// M-Pesa (Safaricom Daraja) payment provider adapter.
//
// Implements the PaymentProviderAdapter interface for M-Pesa Daraja STK Push.
// All provider calls are server-side only. Consumer credentials, passkey and
// shortcode are never exposed to the Flutter application.
//
// Sandbox documentation: https://developer.safaricom.co.ke/docs
// Production: obtain production credentials from Safaricom.

import { loadEnv } from '../../config/env.js';
import { HttpError, ValidationError } from '../../shared/errors.js';
import type {
  PaymentProviderAdapter,
  ProviderCallbackResult,
  ProviderInitiateResult,
  ProviderQueryResult,
} from './payment.provider.js';

const env = loadEnv();

type MpesaEnv = 'sandbox' | 'production';

export function getMpesaConfig(): {
  env: MpesaEnv;
  consumerKey: string;
  consumerSecret: string;
  passkey: string;
  shortcode: string;
  baseUrl: string;
  accountReference: string;
  transactionDesc: string;
  callbackPath: string;
} {
  const mpesaEnv = (env.MPESA_ENV ?? 'sandbox') as MpesaEnv;
  const baseUrl =
    env.MPESA_BASE_URL ??
    (mpesaEnv === 'production'
      ? 'https://api.safaricom.co.ke'
      : 'https://sandbox.safaricom.co.ke');

  if (!env.MPESA_CONSUMER_KEY || !env.MPESA_CONSUMER_SECRET) {
    throw new HttpError('M-Pesa is not configured on this server', 503);
  }
  if (!env.MPESA_PASSKEY) {
    throw new HttpError('M-Pesa passkey is not configured', 503);
  }
  if (!env.MPESA_SHORTCODE) {
    throw new HttpError('M-Pesa shortcode is not configured', 503);
  }

  return {
    env: mpesaEnv,
    consumerKey: env.MPESA_CONSUMER_KEY,
    consumerSecret: env.MPESA_CONSUMER_SECRET,
    passkey: env.MPESA_PASSKEY,
    shortcode: env.MPESA_SHORTCODE,
    baseUrl,
    accountReference: env.MPESA_ACCOUNT_REFERENCE ?? 'GetKeja',
    transactionDesc: env.MPESA_TRANSACTION_DESC ?? 'Rent payment',
    callbackPath: env.MPESA_CALLBACK_PATH ?? '/api/v1/payments/mpesa/callback',
  };
}

let tokenCache: { accessToken: string; expiresAt: number } | null = null;

/**
 * Obtain a Daraja OAuth access token using client credentials.
 * Results are cached briefly and refreshed before expiry.
 */
async function getAccessToken(): Promise<string> {
  const config = getMpesaConfig();
  const now = Date.now();
  if (tokenCache && now < tokenCache.expiresAt - 60_000) {
    return tokenCache.accessToken;
  }

  const credential = Buffer.from(
    `${config.consumerKey}:${config.consumerSecret}`,
  ).toString('base64');

  const url = `${config.baseUrl}/oauth/v1/generate?grant_type=client_credentials`;
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: `Basic ${credential}`,
    },
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new HttpError(
      `M-Pesa token request failed (${response.status}): ${body}`,
      502,
    );
  }

  const data = (await response.json()) as { access_token?: string; expires_in?: string | number };
  if (!data.access_token) {
    throw new HttpError('M-Pesa token response missing access token', 502);
  }

  const expiresIn = Number(data.expires_in ?? 3590) * 1000;
  tokenCache = { accessToken: data.access_token, expiresAt: now + expiresIn };
  return data.access_token;
}

/**
 * Generate the Daraja STK Push password: Base64(Shortcode + Passkey + Timestamp).
 */
function generatePassword(shortcode: string, passkey: string, timestamp: string): string {
  return Buffer.from(`${shortcode}${passkey}${timestamp}`).toString('base64');
}

/**
 * STK Push request payload.
 */
export interface MpesaStkPushRequest {
  phoneNumber: string; // normalized international format, e.g. 2547XXXXXXXX
  amount: number; // KES integer amount
  invoiceReference: string;
  accountReference?: string;
  transactionDesc?: string;
  callbackUrl?: string;
}

/**
 * STK Push initiation response from Daraja.
 */
export interface MpesaStkPushResponse {
  merchantRequestId: string;
  checkoutRequestId: string;
  responseCode: string;
  responseDescription: string;
  customerMessage: string;
}

/**
 * Initiate an M-Pesa STK Push. Returns the provider request identifiers that
 * the caller must persist before returning a pending result to the client.
 */
export async function initiateStkPush(
  request: MpesaStkPushRequest,
): Promise<MpesaStkPushResponse> {
  const config = getMpesaConfig();
  const accessToken = await getAccessToken();

  const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, '');
  const password = generatePassword(config.shortcode, config.passkey, timestamp);

  const phone = normalizeKenyanPhone(request.phoneNumber);
  const amount = Math.round(Number(request.amount));
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpError('Payment amount must be a positive number', 400);
  }

  const payload = {
    BusinessShortCode: config.shortcode,
    Password: password,
    Timestamp: timestamp,
    TransactionType: 'CustomerPayBillOnline',
    Amount: amount,
    PartyA: phone,
    PartyB: config.shortcode,
    PhoneNumber: phone,
    CallBackURL: request.callbackUrl ?? config.callbackPath,
    AccountReference: request.accountReference ?? config.accountReference,
    TransactionDesc: request.transactionDesc ?? config.transactionDesc,
  };

  const url = `${config.baseUrl}/mpesa/stkpush/v1/processrequest`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const bodyText = await response.text();
  let body: unknown;
  try {
    body = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    body = { raw: bodyText };
  }

  if (!response.ok) {
    throw new HttpError(
      `M-Pesa STK push failed (${response.status}): ${JSON.stringify(body)}`,
      502,
    );
  }

  const data = body as {
    MerchantRequestID?: string;
    CheckoutRequestID?: string;
    ResponseCode?: string;
    ResponseDescription?: string;
    CustomerMessage?: string;
  };
  if (!data.MerchantRequestID || !data.CheckoutRequestID) {
    throw new HttpError('M-Pesa STK push response missing identifiers', 502);
  }

  return {
    merchantRequestId: data.MerchantRequestID,
    checkoutRequestId: data.CheckoutRequestID,
    responseCode: data.ResponseCode ?? '',
    responseDescription: data.ResponseDescription ?? '',
    customerMessage: data.CustomerMessage ?? '',
  };
}

/**
 * Query the status of an M-Pesa transaction via the Daraja transaction status
 * endpoint. Used for reconciliation of ambiguous or missing callbacks.
 */
export interface MpesaQueryStatusRequest {
  checkoutRequestId?: string;
  transactionReference?: string; // internal reference fallback
}

export interface MpesaQueryStatusResponse {
  responseCode: string;
  responseDescription: string;
  merchantRequestId: string | null;
  checkoutRequestId: string | null;
  transactionDate?: string | null;
  transactionReceipt?: string | null;
  amount?: number | null;
  msisdn?: string | null;
}

export async function queryTransactionStatus(
  checkoutRequestId: string,
): Promise<MpesaQueryStatusResponse> {
  const config = getMpesaConfig();
  const accessToken = await getAccessToken();

  const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, '');
  const password = generatePassword(config.shortcode, config.passkey, timestamp);

  const payload = {
    BusinessShortCode: config.shortcode,
    Password: password,
    Timestamp: timestamp,
    CheckoutRequestID: checkoutRequestId,
  };

  const url = `${config.baseUrl}/mpesa/stkpushquery/v1/query`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    const bodyText = await response.text().catch(() => '');
    body = bodyText ? JSON.parse(bodyText) : {};
  }

  if (!response.ok) {
    throw new HttpError(
      `M-Pesa transaction status query failed (${response.status}): ${JSON.stringify(body)}`,
      502,
    );
  }

  const data = body as {
    ResponseCode?: string;
    ResponseDescription?: string;
    MerchantRequestID?: string;
    CheckoutRequestID?: string;
    TransactionDate?: string;
    TransactionReceipt?: string;
    Amount?: number;
    MSISDN?: string;
  };

  return {
    responseCode: data.ResponseCode ?? '',
    responseDescription: data.ResponseDescription ?? '',
    merchantRequestId: data.MerchantRequestID ?? null,
    checkoutRequestId: data.CheckoutRequestID ?? null,
    transactionDate: data.TransactionDate ?? null,
    transactionReceipt: data.TransactionReceipt ?? null,
    amount: data.Amount ?? null,
    msisdn: data.MSISDN ?? null,
  };
}

/**
 * Normalize a Kenyan phone number to international format without leading +,
 * e.g. "0712345678" or "+254712345678" -> "254712345678".
 * Throws ValidationError for invalid numbers.
 */
export function normalizeKenyanPhone(value: string): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new ValidationError('Phone number is required');
  }
  let cleaned = value.trim().replace(/\s+/g, '');
  if (cleaned.startsWith('+')) cleaned = cleaned.slice(1);
  if (cleaned.startsWith('00')) cleaned = cleaned.slice(2);
  if (cleaned.startsWith('254')) {
    // already international
  } else if (cleaned.startsWith('0')) {
    cleaned = '254' + cleaned.slice(1);
  } else if (/^[71]\d{8}$/.test(cleaned)) {
    cleaned = '254' + cleaned;
  }
  if (!/^254[17]\d{8}$/.test(cleaned)) {
    throw new ValidationError(
      'Invalid Kenyan phone number (use 07XX XXX XXX or +2547XX XXX XXX)',
    );
  }
  return cleaned;
}

// ============================================================================
// PaymentProviderAdapter implementation for M-Pesa Daraja
// ============================================================================

export const mpesaDarajaAdapter: PaymentProviderAdapter = {
  provider: 'mpesa',
  displayName: 'M-Pesa STK Push (Daraja)',

  async initiatePayment(input): Promise<ProviderInitiateResult> {
    const response = await initiateStkPush({
      phoneNumber: input.phoneNumber!,
      amount: Math.round(input.amount),
      invoiceReference: input.invoiceReference ?? 'GetKeja',
      accountReference: input.accountReference,
      transactionDesc: input.transactionDesc,
    });
    return {
      providerTransactionId: response.checkoutRequestId,
      merchantRequestId: response.merchantRequestId,
      status: 'pending',
      rawResponse: {
        responseCode: response.responseCode,
        responseDescription: response.responseDescription,
        customerMessage: response.customerMessage,
      },
    };
  },

  async queryTransactionStatus(input): Promise<ProviderQueryResult> {
    const result = await queryTransactionStatus(input.providerTransactionId);
    return {
      successful: result.responseCode === '0',
      transactionReceipt: result.transactionReceipt ?? null,
      responseCode: result.responseCode ?? null,
      transactionDate: result.transactionDate ?? null,
      amount: result.amount ?? null,
      currency: 'KES',
      msisdn: result.msisdn ?? null,
      failureReason: result.responseCode !== '0' ? result.responseDescription : null,
      rawResponse: {
        responseDescription: result.responseDescription,
        merchantRequestId: result.merchantRequestId,
      },
    };
  },

  async handleCallback(body): Promise<ProviderCallbackResult> {
    const callback = body as {
      MerchantRequestID?: string;
      CheckoutRequestID?: string;
      ResultCode?: number | string;
      ResultDesc?: string;
      CallbackMetadata?: {
        Item?: Array<{ Name: string; Value: unknown }>;
      };
    };

    const checkoutRequestId = callback.CheckoutRequestID;
    if (!checkoutRequestId) {
      return {
        providerTransactionId: '',
        successful: false,
        alreadyProcessed: false,
        rawPayload: body as Record<string, unknown>,
      };
    }

    const resultCode = callback.ResultCode;
    const resultDesc = callback.ResultDesc ?? '';
    const resultCodeNum = Number(resultCode);
    const isSuccess = resultCodeNum === 0;

    let amount: number | null = null;
    let mpesaReceipt: string | null = null;
    let transactionDate: Date | null = null;
    let phoneNumber: string | null = null;
    const items = callback.CallbackMetadata?.Item ?? [];
    for (const item of items) {
      if (item.Name === 'Amount') amount = Number(item.Value);
      if (item.Name === 'MpesaReceiptNumber') mpesaReceipt = String(item.Value ?? '');
      if (item.Name === 'TransactionDate') {
        transactionDate = parseMpesaTimestamp(String(item.Value ?? ''));
      }
      if (item.Name === 'PhoneNumber') phoneNumber = String(item.Value ?? '');
    }

    return {
      providerTransactionId: checkoutRequestId,
      successful: isSuccess,
      providerReceipt: mpesaReceipt ?? undefined,
      transactionDate,
      amount: amount ?? undefined,
      phoneNumber,
      rawPayload: (body ?? {}) as Record<string, unknown>,
    };
  },
};

function parseMpesaTimestamp(value: string | null): Date | null {
  if (!value || value.length < 14) return null;
  return new Date(
    `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:${value.slice(12, 14)}Z`,
  );
}

/**
 * C2B URL registration request for Safaricom Daraja.
 * Registers validation and confirmation URLs for M-Pesa Paybill/C2B.
 */
export interface MpesaC2BRegisterRequest {
  shortCode: string;
  responseType: 'Completed' | 'Cancelled';
  confirmationUrl: string;
  validationUrl: string;
}

export interface MpesaC2BRegisterResponse {
  ConversationID: string;
  OriginatorConversationID: string;
  ResponseCode: string;
  ResponseDescription: string;
}

/**
 * Register C2B validation and confirmation URLs with Safaricom Daraja.
 * Required before Paybill/C2B callbacks can be received.
 * 
 * Sandbox: https://developer.safaricom.co.ke/test_apis (C2B URL Registration)
 * Production: Requires Safaricom portal approval of the Paybill number.
 */
export async function registerC2BUrls(
  request: MpesaC2BRegisterRequest,
): Promise<MpesaC2BRegisterResponse> {
  const config = getMpesaConfig();
  const accessToken = await getAccessToken();

  const payload = {
    ShortCode: request.shortCode ?? config.shortcode,
    ResponseType: request.responseType,
    ConfirmationURL: request.confirmationUrl,
    ValidationURL: request.validationUrl,
  };

  const url = `${config.baseUrl}/mpesa/c2b/v1/registerurl`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const bodyText = await response.text();
  let body: unknown;
  try {
    body = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    body = { raw: bodyText };
  }

  if (!response.ok) {
    throw new HttpError(
      `M-Pesa C2B URL registration failed (${response.status}): ${JSON.stringify(body)}`,
      502,
    );
  }

  const data = body as {
    ConversationID?: string;
    OriginatorConversationID?: string;
    ResponseCode?: string;
    ResponseDescription?: string;
  };

  return {
    ConversationID: data.ConversationID ?? '',
    OriginatorConversationID: data.OriginatorConversationID ?? '',
    ResponseCode: data.ResponseCode ?? '',
    ResponseDescription: data.ResponseDescription ?? '',
  };
}

/**
 * Round to 2 decimal places exactly (KES). Avoids float drift.
 */
function money(value: number): number {
  return Math.round(value * 100) / 100;
}

export { money };

/**
 * M-Pesa Paybill C2B provider adapter.
 *
 * Paybill C2B callbacks use a different format than STK Push:
 *   TransactionType, TransID, TransTime, TransAmount, BusinessShortCode,
 *   BillRefNumber, InvoiceNumber, FirstName, MiddleName, LastName, MSISDN
 *
 * The provider transaction reference is TransID.
 * The account reference is BillRefNumber or InvoiceNumber (used to match to invoice).
 *
 * C2B is customer-initiated: there is no server-side STK Push initiation.
 * The tenant pays directly to the Paybill using the account reference.
 * Status is determined solely by the confirmation callback (no query API).
 */
export const mpesaPaybillAdapter: PaymentProviderAdapter = {
  provider: 'mpesa_paybill',
  displayName: 'M-Pesa Paybill (C2B)',

  async initiatePayment(input): Promise<ProviderInitiateResult> {
    // C2B is customer-initiated: there is no server-side initiation.
    // The tenant pays directly to the Paybill using the account reference.
    // Return a pending reference that will be matched when the callback arrives.
    const merchantReference = input.merchantReference ?? `GK-${Date.now()}`;
    return {
      providerTransactionId: merchantReference,
      merchantRequestId: undefined,
      status: 'pending',
      rawResponse: {
        instruction: `Pay to Paybill ${configShortcode()} using Account Reference: ${merchantReference}`,
      },
    };
  },

  async queryTransactionStatus(input): Promise<ProviderQueryResult> {
    // C2B does not have a transaction status query API.
    // Status is determined solely by the confirmation callback.
    return {
      successful: false,
      transactionReceipt: null,
      responseCode: null,
      transactionDate: null,
      amount: null,
      currency: 'KES',
      msisdn: null,
      failureReason: 'C2B status query not supported; await confirmation callback',
      rawResponse: {},
    };
  },

  async handleCallback(body): Promise<ProviderCallbackResult> {
    const callback = body as {
      TransactionType?: string;
      TransID?: string;
      TransTime?: string;
      TransAmount?: number;
      BusinessShortCode?: string;
      BillRefNumber?: string;
      InvoiceNumber?: string;
      FirstName?: string;
      MiddleName?: string;
      LastName?: string;
      MSISDN?: string;
      [key: string]: unknown;
    };

    const transId = callback.TransID;
    if (!transId) {
      return {
        providerTransactionId: '',
        successful: false,
        alreadyProcessed: false,
        rawPayload: (body ?? {}) as Record<string, unknown>,
      };
    }

    // C2B confirmation: TransactionType 'PayBill' or 'BuyGoods' with valid TransID
    // indicates the provider accepted the payment. Amount validation happens
    // in the orchestration service against the internal payment attempt.
    const isSuccess =
      (callback.TransactionType === 'PayBill' ||
        callback.TransactionType === 'BuyGoods') &&
      !!callback.TransID;

    return {
      providerTransactionId: transId,
      successful: isSuccess,
      providerReceipt: transId,
      transactionDate: parseC2BTimestamp(callback.TransTime ?? null),
      amount: callback.TransAmount != null ? Number(callback.TransAmount) : undefined,
      phoneNumber: callback.MSISDN != null ? normalizeKenyanPhone(String(callback.MSISDN)) : undefined,
      rawPayload: (body ?? {}) as Record<string, unknown>,
    };
  },
};

/**
 * Parse Safaricom C2B TransTime format (YYYYMMDDHHMMSS) to Date.
 */
function parseC2BTimestamp(value: string | null): Date | null {
  if (!value || value.length < 14) return null;
  return new Date(
    `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:${value.slice(12, 14)}Z`,
  );
}

/**
 * Return the configured M-Pesa shortcode (used for Paybill/Till display).
 */
function configShortcode(): string {
  try {
    return getMpesaConfig().shortcode;
  } catch {
    return '';
  }
}

/**
 * M-Pesa Buy Goods Till provider adapter.
 *
 * Till (Buy Goods) callbacks use a format similar to Paybill C2B:
 *   TransactionType, TransID, TransTime, TransAmount, BusinessShortCode,
 *   BillRefNumber, InvoiceNumber, FirstName, MiddleName, LastName, MSISDN
 *
 * The provider transaction reference is TransID.
 * Till is customer-initiated: the tenant pays directly to the Till number.
 * Status is determined solely by the confirmation callback (no query API).
 *
 * Distinguished from Paybill by TransactionType 'BuyGoods' vs 'PayBill'.
 */
export const mpesaTillAdapter: PaymentProviderAdapter = {
  provider: 'mpesa_till',
  displayName: 'M-Pesa Buy Goods Till',

  async initiatePayment(input): Promise<ProviderInitiateResult> {
    // Till is customer-initiated: there is no server-side initiation.
    // The tenant pays directly to the Till using the account reference.
    const merchantReference = input.merchantReference ?? `GK-${Date.now()}`;
    return {
      providerTransactionId: merchantReference,
      merchantRequestId: undefined,
      status: 'pending',
      rawResponse: {
        instruction: `Pay to Till ${configShortcode()} using Account Reference: ${merchantReference}`,
      },
    };
  },

  async queryTransactionStatus(input): Promise<ProviderQueryResult> {
    // Till does not have a transaction status query API.
    return {
      successful: false,
      transactionReceipt: null,
      responseCode: null,
      transactionDate: null,
      amount: null,
      currency: 'KES',
      msisdn: null,
      failureReason: 'Till status query not supported; await confirmation callback',
      rawResponse: {},
    };
  },

  async handleCallback(body): Promise<ProviderCallbackResult> {
    const callback = body as {
      TransactionType?: string;
      TransID?: string;
      TransTime?: string;
      TransAmount?: number;
      BusinessShortCode?: string;
      BillRefNumber?: string;
      InvoiceNumber?: string;
      FirstName?: string;
      MiddleName?: string;
      LastName?: string;
      MSISDN?: string;
      [key: string]: unknown;
    };

    const transId = callback.TransID;
    if (!transId) {
      return {
        providerTransactionId: '',
        successful: false,
        alreadyProcessed: false,
        rawPayload: (body ?? {}) as Record<string, unknown>,
      };
    }

    // Till confirmation: TransactionType 'BuyGoods' with valid TransID
    // indicates the provider accepted the payment.
    const isSuccess = callback.TransactionType === 'BuyGoods' && !!callback.TransID;

    return {
      providerTransactionId: transId,
      successful: isSuccess,
      providerReceipt: transId,
      transactionDate: parseC2BTimestamp(callback.TransTime ?? null),
      amount: callback.TransAmount != null ? Number(callback.TransAmount) : undefined,
      phoneNumber: callback.MSISDN != null ? normalizeKenyanPhone(String(callback.MSISDN)) : undefined,
      rawPayload: (body ?? {}) as Record<string, unknown>,
    };
  },
};
