// Recurring billing calculations.
//
// All monetary math is performed on integer cents (bigint) parsed from decimal
// strings. JavaScript floating-point is never used for monetary totals or
// proration. PostgreSQL NUMERIC/DECIMAL values arrive as strings from `pg`, so
// parsing the string to cents is exact.

export type BillingFrequency = 'monthly' | 'quarterly' | 'annual';

export interface BillingPeriod {
  start: string; // YYYY-MM-DD
  end: string; // YYYY-MM-DD (inclusive)
}

const MS_PER_DAY = 86_400_000;

/** Parse a decimal money value (number or string) into integer cents. */
export function toCents(value: number | string): bigint {
  const str = typeof value === 'number' ? decimalToString(value) : value;
  const negative = str.trim().startsWith('-');
  const cleaned = str.trim().replace(/^[+-]/, '');
  const [wholeRaw = '0', fracRaw = ''] = cleaned.split('.');
  const whole = BigInt(wholeRaw || '0');
  const frac = (fracRaw + '00').slice(0, 2);
  const cents = whole * 100n + BigInt(frac || '0');
  return negative ? -cents : cents;
}

/** Format integer cents as a fixed 2-decimal string (no float). */
export function centsToString(cents: bigint): string {
  const negative = cents < 0n;
  const abs = negative ? -cents : cents;
  const whole = abs / 100n;
  const frac = (abs % 100n).toString().padStart(2, '0');
  return `${negative ? '-' : ''}${whole.toString()}.${frac}`;
}

/** Convert integer cents to a JS number only at the storage boundary. */
export function centsToNumber(cents: bigint): number {
  return Number(centsToString(cents));
}

function decimalToString(value: number): string {
  // Convert a JS number to a plain decimal string without exponent notation.
  if (!Number.isFinite(value)) throw new Error('Invalid monetary number');
  return value.toFixed(2);
}

/** Round (numerator / denominator) half-up for non-negative bigints. */
function roundHalfUp(numerator: bigint, denominator: bigint): bigint {
  if (denominator <= 0n) throw new Error('Invalid denominator');
  return (numerator + denominator / 2n) / denominator;
}

// ---- Date helpers (UTC, date-only) ----

export function isValidDateStr(s: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(`${s}T00:00:00Z`));
}

export function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export function diffDays(a: string, b: string): number {
  return Math.round(
    (Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`)) / MS_PER_DAY,
  );
}

export function daysInMonth(year: number, month1: number): number {
  // month1 is 1-12.
  return new Date(Date.UTC(year, month1, 0)).getUTCDate();
}

/** Add months to a date, clamping the day-of-month to the target month length. */
export function addMonthsClamped(dateStr: string, months: number, preferredDay?: number): string {
  const parts = dateStr.split('-');
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  const d = Number(parts[2]);
  const base = new Date(Date.UTC(y, m - 1, 1));
  base.setUTCMonth(base.getUTCMonth() + months);
  const targetYear = base.getUTCFullYear();
  const targetMonth = base.getUTCMonth() + 1; // 1-12
  const day = Math.min(preferredDay ?? d, daysInMonth(targetYear, targetMonth));
  const mm = String(targetMonth).padStart(2, '0');
  const dd = String(day).padStart(2, '0');
  return `${targetYear}-${mm}-${dd}`;
}

export function monthsBetween(frequency: BillingFrequency): number {
  switch (frequency) {
    case 'monthly':
      return 1;
    case 'quarterly':
      return 3;
    case 'annual':
      return 12;
    default:
      return 1;
  }
}

/** Inclusive period end for a period starting at `start` with the frequency. */
export function periodEnd(start: string, frequency: BillingFrequency): string {
  return addDays(addMonthsClamped(start, monthsBetween(frequency)), -1);
}

/** The period start that follows `start`. */
export function nextPeriodStart(start: string, frequency: BillingFrequency, billingDay: number): string {
  return addMonthsClamped(start, monthsBetween(frequency), billingDay);
}

/**
 * Compute the invoice due date.
 * - If dueDayOfMonth is set, due on that day within the period-start month.
 * - Otherwise due on the billing day within the period-start month.
 * - gracePeriodDays extends the due date.
 */
export function computeDueDate(
  periodStart: string,
  billingDay: number,
  dueDayOfMonth: number | null,
  gracePeriodDays: number,
): string {
  const parts = periodStart.split('-');
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  const day = Math.min(dueDayOfMonth ?? billingDay, daysInMonth(y, m));
  const mm = String(m).padStart(2, '0');
  const dd = String(day).padStart(2, '0');
  const base = `${y}-${mm}-${dd}`;
  return addDays(base, gracePeriodDays);
}

/**
 * Prorate the rent for a (possibly partial) billing period, clamped to the
 * tenancy's active range. Convention: actual-days / actual-days-in-month
 * (per-diem within the calendar month of the period start). The first and last
 * partial periods are prorated by occupied days and never overlap.
 *
 * Returns integer cents.
 */
export function prorateRentCents(
  rentCents: bigint,
  period: BillingPeriod,
  tenancyStart: string,
  tenancyEnd: string | null,
): bigint {
  // Clamp the billable window to the tenancy.
  const billableStart = period.start > tenancyStart ? period.start : tenancyStart;
  let billableEnd = period.end;
  if (tenancyEnd && billableEnd > tenancyEnd) billableEnd = tenancyEnd;
  if (billableStart > billableEnd) return 0n; // no overlap with tenancy

  const occupiedDays = diffDays(billableEnd, billableStart) + 1;

  // Full-period length for the per-diem basis: use the calendar month of the
  // period start (monthly basis). For a full, unprorated period this yields
  // exactly the rent.
  const parts = period.start.split('-');
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  const basisDays = daysInMonth(y, m);

  if (occupiedDays >= basisDays && period.start >= tenancyStart && (!tenancyEnd || period.end <= tenancyEnd)) {
    return rentCents; // full period within tenancy
  }

  return roundHalfUp(rentCents * BigInt(occupiedDays), BigInt(basisDays));
}

/**
 * Enumerate candidate period starts within [fromDate, toDate] (inclusive) for a
 * schedule, starting at firstBillingDate. Bounded to avoid runaway loops.
 */
export function enumeratePeriodStarts(
  firstBillingDate: string,
  billingDay: number,
  frequency: BillingFrequency,
  fromDate: string,
  toDate: string,
  maxIterations = 1200,
): string[] {
  const starts: string[] = [];
  let cursor = firstBillingDate;
  let guard = 0;
  while (cursor <= toDate && guard < maxIterations) {
    guard += 1;
    if (cursor >= fromDate) starts.push(cursor);
    const next = nextPeriodStart(cursor, frequency, billingDay);
    if (next <= cursor) break; // safety against non-advancing
    cursor = next;
  }
  return starts;
}