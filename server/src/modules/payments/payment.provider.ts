// Payment provider adapter interface.
//
// All payment providers (M-Pesa Daraja, M-Pesa Paybill, M-Pesa Till, Pesapal)
// implement this interface. The payment orchestration service owns all
// financial logic (invoice allocation, ledger, receipts); adapters only
// handle provider communication and response normalization.

export interface PaymentProviderAdapter {
  /** Stable provider identifier, e.g. 'mpesa_daraja', 'pesapal', 'mpesa_paybill' */
  readonly provider: string;

  /** Human-readable display name */
  readonly displayName: string;

  /** Initiate a payment request to the provider. Returns provider-specific
   *  references needed to track the asynchronous transaction. */
  initiatePayment(input: {
    amount: number; // minor currency units, KES
    phoneNumber?: string;
    invoiceReference?: string;
    accountReference?: string;
    transactionDesc?: string;
    merchantReference?: string;
  }): Promise<ProviderInitiateResult>;

  /** Query the provider for the status of a transaction. */
  queryTransactionStatus(input: {
    providerTransactionId: string;
  }): Promise<ProviderQueryResult>;

  /** Handle an incoming callback/webhook from the provider. Returns a
   *  normalized result the orchestration service can act on. */
  handleCallback(body: unknown): Promise<ProviderCallbackResult>;

  /** Register webhook/IPN URLs with the provider (sandbox setup). */
  registerWebhooks?(): Promise<void>;
}

/** Result of provider payment initiation. */
export interface ProviderInitiateResult {
  /** Provider's transaction/checkout reference (stable identifier). */
  providerTransactionId: string;
  /** Provider's merchant request ID (if applicable). */
  merchantRequestId?: string;
  /** Checkout/hosted payment URL (for redirect-based flows like Pesapal). */
  checkoutUrl?: string;
  /** Normalized status after initiation. */
  status: 'pending';
  /** Any additional provider-specific data to store. */
  rawResponse?: Record<string, unknown>;
}

/** Result of provider transaction status query. */
export interface ProviderQueryResult {
  /** Whether the provider confirms the transaction as successful. */
  successful: boolean;
  /** Provider transaction receipt/reference number. */
  transactionReceipt?: string | null;
  /** Provider response code (provider-specific). */
  responseCode?: string | null;
  /** Transaction date/time from the provider. */
  transactionDate?: string | null;
  /** Amount confirmed by the provider. */
  amount?: number | null;
  /** Currency confirmed by the provider. */
  currency?: string | null;
  /** Phone number/MSISDN from the provider. */
  msisdn?: string | null;
  /** Failure reason if unsuccessful. */
  failureReason?: string | null;
  /** Raw provider response. */
  rawResponse?: Record<string, unknown>;
}

/** Normalized result of a provider callback. */
export interface ProviderCallbackResult {
  /** Provider transaction reference. */
  providerTransactionId: string;
  /** Whether the callback indicates success. */
  successful: boolean;
  /** Provider receipt number (if available). */
  providerReceipt?: string | null;
  /** Transaction date from the callback. */
  transactionDate?: Date | null;
  /** Amount from the callback. */
  amount?: number | null;
  /** Phone number from the callback. */
  phoneNumber?: string | null;
  /** Raw callback payload. */
  rawPayload: Record<string, unknown>;
  /** Whether this callback should be treated as already processed (idempotent). */
  alreadyProcessed?: boolean;
}
