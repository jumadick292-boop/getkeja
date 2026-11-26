// Pesapal payment provider adapter (API 3.0).
//
// Implements the PaymentProviderAdapter interface for Pesapal payment gateway.
// All provider calls are server-side only. Consumer credentials are never
// exposed to the Flutter application.
//
// Sandbox documentation: https://developer.pesapal.com
// Production: obtain production credentials from Pesapal.

import { loadEnv } from '../../config/env.js';
import { HttpError } from '../../shared/errors.js';
import type {
  PaymentProviderAdapter,
  ProviderCallbackResult,
  ProviderInitiateResult,
  ProviderQueryResult,
} from './payment.provider.js';

const env = loadEnv();

type PesapalEnv = 'sandbox' | 'production';

function getPesapalConfig(): {
  env: PesapalEnv;
  consumerKey: string;
  consumerSecret: string;
  baseUrl: string;
  callbackPath: string;
  ipnPath: string;
} {
  const pesapalEnv = (env.PESAPAL_ENV ?? 'sandbox') as PesapalEnv;
  const baseUrl =
    env.PESAPAL_BASE_URL ??
    (pesapalEnv === 'production'
      ? 'https://pay.pesapal.com/v3'
      : 'https://cybqa.pesapal.com/pesapalpva');

  if (!env.PESAPAL_CONSUMER_KEY || !env.PESAPAL_CONSUMER_SECRET) {
    throw new HttpError('Pesapal is not configured on this server', 503);
  }

  return {
    env: pesapalEnv,
    consumerKey: env.PESAPAL_CONSUMER_KEY,
    consumerSecret: env.PESAPAL_CONSUMER_SECRET,
    baseUrl,
    callbackPath: env.PESAPAL_CALLBACK_PATH ?? '/api/v1/payments/pesapal/callback',
    ipnPath: env.PESAPAL_IPN_PATH ?? '/api/v1/payments/pesapal/ipn',
  };
}

let tokenCache: { accessToken: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  const config = getPesapalConfig();
  const now = Date.now();
  if (tokenCache && now < tokenCache.expiresAt - 60_000) {
    return tokenCache.accessToken;
  }

  const url = `${config.baseUrl}/api/Authenticate/RequestToken`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      consumer_key: config.consumerKey,
      consumer_secret: config.consumerSecret,
    }),
  });

  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new HttpError(
      `Pesapal token request failed (${response.status}): ${body}`,
      502,
    );
  }

  const data = (await response.json()) as {
    token?: string;
    expiryDate?: string;
  };
  if (!data.token) {
    throw new HttpError('Pesapal token response missing token', 502);
  }

  const expiresAt = data.expiryDate ? new Date(data.expiryDate).getTime() : now + 3_600_000;
  tokenCache = { accessToken: data.token, expiresAt };
  return data.token;
}

async function requestPesapal<T>(
  method: 'GET' | 'POST',
  path: string,
  body?: unknown,
): Promise<T> {
  const accessToken = await getAccessToken();
  const config = getPesapalConfig();
  const url = `${config.baseUrl}${path}`;

  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  const bodyText = await response.text();
  let data: unknown;
  try {
    data = bodyText ? JSON.parse(bodyText) : {};
  } catch {
    data = { raw: bodyText };
  }

  if (!response.ok) {
    throw new HttpError(
      `Pesapal API error (${response.status}): ${JSON.stringify(data)}`,
      502,
    );
  }

  return data as T;
}

export interface PesapalIPNRegisterRequest {
  url: string;
  ipn_notification_type: 'GET' | 'POST';
}

export interface PesapalIPNRegisterResponse {
  ipn_id: string;
  url: string;
  ipn_notification_type: string;
  status: string;
}

export async function registerPesapalIPN(
  request: PesapalIPNRegisterRequest,
): Promise<PesapalIPNRegisterResponse> {
  return requestPesapal<PesapalIPNRegisterResponse>(
    'POST',
    '/api/SetupIPN/RegisterIPN',
    {
      url: request.url,
      ipn_notification_type: request.ipn_notification_type,
    },
  );
}
export interface PesapalOrderRequest {
  id: string; // unique merchant reference
  currency: string;
  amount: number;
  description: string;
  callback_url: string;
  notification_id?: string; // IPN ID from registration
  billing_address?: {
    email_address?: string;
    phone_number?: string;
    country_code?: string;
  };
}

export interface PesapalOrderResponse {
  order_tracking_id: string;
  order_merchand_reference: string;
  redirect_url: string;
}

export async function createPesapalOrder(
  request: PesapalOrderRequest,
): Promise<PesapalOrderResponse> {
  return requestPesapal<PesapalOrderResponse>('POST', '/api/Transactions/SubmitOrderRequest', {
    id: request.id,
    currency: request.currency,
    amount: request.amount,
    description: request.description,
    callback_url: request.callback_url,
    notification_id: request.notification_id,
    billing_address: request.billing_address,
  });
}

export interface PesapalTransactionStatus {
  order_tracking_id: string;
  order_merchand_reference: string;
  payment_status_code: string;
  payment_status_description: string;
  payment_method: string;
  payment_account?: string;
  amount: number;
  currency: string;
  created_date: string;
  updated_date: string;
  confirmation_code?: string;
}

export async function queryPesapalTransactionStatus(
  orderTrackingId: string,
): Promise<PesapalTransactionStatus> {
  return requestPesapal<PesapalTransactionStatus>(
    'GET',
    `/api/Transactions/GetTransactionStatus?orderTrackingId=${encodeURIComponent(orderTrackingId)}`,
  );
}

// ============================================================================
// PaymentProviderAdapter implementation for Pesapal
// ============================================================================

export const pesapalAdapter: PaymentProviderAdapter = {
  provider: 'pesapal',
  displayName: 'Pesapal',

  async initiatePayment(input): Promise<ProviderInitiateResult> {
    const config = getPesapalConfig();
    const merchantReference = input.merchantReference ?? `GK-${Date.now()}`;

    const response = await createPesapalOrder({
      id: merchantReference,
      currency: 'KES',
      amount: Math.round(input.amount),
      description: input.invoiceReference ?? 'GetKeja payment',
      callback_url: config.callbackPath,
      notification_id: env.PESAPAL_NOTIFICATION_ID,
      billing_address: input.phoneNumber
        ? {
            phone_number: input.phoneNumber,
            country_code: 'KE',
          }
        : undefined,
    });

    return {
      providerTransactionId: response.order_tracking_id,
      merchantRequestId: response.order_merchand_reference,
      checkoutUrl: response.redirect_url,
      status: 'pending',
      rawResponse: {
        orderTrackingId: response.order_tracking_id,
        redirectUrl: response.redirect_url,
      },
    };
  },

  async queryTransactionStatus(input): Promise<ProviderQueryResult> {
    const result = await queryPesapalTransactionStatus(input.providerTransactionId);
    const successful = result.payment_status_code === 'COMPLETED';

    return {
      successful,
      transactionReceipt: result.confirmation_code ?? null,
      responseCode: result.payment_status_code ?? null,
      transactionDate: result.updated_date ?? null,
      amount: result.amount ?? null,
      currency: result.currency ?? null,
      msisdn: result.payment_account ?? null,
      failureReason: successful
        ? null
        : result.payment_status_description,
      rawResponse: {
        paymentMethod: result.payment_method,
        paymentStatusCode: result.payment_status_code,
        paymentStatusDescription: result.payment_status_description,
        orderMerchReference: result.order_merchand_reference,
      },
    };
  },

  async handleCallback(body): Promise<ProviderCallbackResult> {
    const callback = body as {
      OrderTrackingId?: string;
      OrderMerchantReference?: string;
      PaymentStatusCode?: string;
      PaymentStatusDescription?: string;
      PaymentMethod?: string;
      PaymentAccount?: string;
      Amount?: number;
      Currency?: string;
      ConfirmationCode?: string;
      [key: string]: unknown;
    };

    const orderTrackingId = callback.OrderTrackingId;
    if (!orderTrackingId) {
      return {
        providerTransactionId: '',
        successful: false,
        alreadyProcessed: false,
        rawPayload: (body ?? {}) as Record<string, unknown>,
      };
    }

    const isSuccess = callback.PaymentStatusCode === 'COMPLETED';

    return {
      providerTransactionId: orderTrackingId,
      successful: isSuccess,
      providerReceipt: callback.ConfirmationCode ?? undefined,
      transactionDate: undefined,
      amount: callback.Amount ?? undefined,
      phoneNumber: callback.PaymentAccount ?? undefined,
      rawPayload: (body ?? {}) as Record<string, unknown>,
    };
  },
};
