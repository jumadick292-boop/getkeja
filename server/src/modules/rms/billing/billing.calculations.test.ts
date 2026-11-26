// Unit tests for recurring billing calculations (Task 14.1).
// Pure functions only — no database required.
import { describe, expect, it } from 'vitest';
import {
  addDays,
  addMonthsClamped,
  centsToString,
  computeDueDate,
  daysInMonth,
  enumeratePeriodStarts,
  nextPeriodStart,
  periodEnd,
  prorateRentCents,
  toCents,
} from './billing.calculations.js';

describe('money cents conversion (no float totals)', () => {
  it('parses decimal strings to integer cents exactly', () => {
    expect(toCents('15000.00')).toBe(1500000n);
    expect(toCents('2500.5')).toBe(250050n);
    expect(toCents('0.01')).toBe(1n);
    expect(toCents(3100)).toBe(310000n);
  });

  it('formats cents back to a 2-decimal string', () => {
    expect(centsToString(1500000n)).toBe('15000.00');
    expect(centsToString(1n)).toBe('0.01');
    expect(centsToString(0n)).toBe('0.00');
  });
});

describe('date helpers', () => {
  it('adds days across month boundaries', () => {
    expect(addDays('2026-01-31', 1)).toBe('2026-02-01');
  });

  it('clamps month addition to month length', () => {
    expect(addMonthsClamped('2026-01-31', 1)).toBe('2026-02-28');
    expect(addMonthsClamped('2024-01-31', 1)).toBe('2024-02-29'); // leap year
    expect(addMonthsClamped('2026-01-15', 1, 1)).toBe('2026-02-01');
  });

  it('computes days in month', () => {
    expect(daysInMonth(2026, 2)).toBe(28);
    expect(daysInMonth(2024, 2)).toBe(29);
    expect(daysInMonth(2026, 1)).toBe(31);
  });

  it('computes inclusive period end per frequency', () => {
    expect(periodEnd('2026-01-01', 'monthly')).toBe('2026-01-31');
    expect(periodEnd('2026-01-01', 'quarterly')).toBe('2026-03-31');
    expect(periodEnd('2026-01-01', 'annual')).toBe('2026-12-31');
  });

  it('advances to the next period start', () => {
    expect(nextPeriodStart('2026-01-01', 'monthly', 1)).toBe('2026-02-01');
    expect(nextPeriodStart('2026-01-31', 'monthly', 31)).toBe('2026-02-28');
  });

  it('enumerates monthly period starts within a window', () => {
    expect(enumeratePeriodStarts('2026-01-01', 1, 'monthly', '2026-01-01', '2026-03-31')).toEqual([
      '2026-01-01',
      '2026-02-01',
      '2026-03-01',
    ]);
  });
});

describe('due date calculation', () => {
  it('uses the billing day within the period-start month by default', () => {
    expect(computeDueDate('2026-02-10', 1, null, 0)).toBe('2026-02-01');
    expect(computeDueDate('2026-02-10', 5, null, 0)).toBe('2026-02-05');
  });

  it('honours an explicit due day of month', () => {
    expect(computeDueDate('2026-02-10', 1, 5, 0)).toBe('2026-02-05');
  });

  it('clamps the due day to month length', () => {
    expect(computeDueDate('2026-02-10', 28, 28, 0)).toBe('2026-02-28');
  });

  it('adds the grace period to the due date', () => {
    expect(computeDueDate('2026-02-01', 1, null, 3)).toBe('2026-02-04');
  });
});

describe('proration (actual-days basis, clamped to tenancy)', () => {
  it('charges full rent for a full period inside the tenancy', () => {
    const cents = prorateRentCents(310000n, { start: '2026-01-01', end: '2026-01-31' }, '2026-01-01', null);
    expect(cents).toBe(310000n);
  });

  it('prorates the first partial period by occupied days', () => {
    // January (31 days), rent 3100, tenancy starts 16th -> 16 occupied days.
    const cents = prorateRentCents(310000n, { start: '2026-01-01', end: '2026-01-31' }, '2026-01-16', null);
    expect(cents).toBe(160000n); // 310000 * 16 / 31 = 160000 exactly
  });

  it('rounds half-up on uneven proration', () => {
    // February 2026 (28 days), rent 1500, tenancy starts 10th -> 19 days.
    // 150000 * 19 / 28 = 101785.71... -> 101786
    const cents = prorateRentCents(150000n, { start: '2026-02-01', end: '2026-02-28' }, '2026-02-10', null);
    expect(cents).toBe(101786n);
  });

  it('clamps to the tenancy end date', () => {
    // Period extends past tenancy end on the 10th -> 10 occupied days of 31.
    const cents = prorateRentCents(310000n, { start: '2026-01-01', end: '2026-01-31' }, '2026-01-01', '2026-01-10');
    expect(cents).toBe(100000n); // 310000 * 10 / 31 = 100000 exactly
  });

  it('returns zero when the period does not overlap the tenancy', () => {
    const cents = prorateRentCents(310000n, { start: '2026-02-01', end: '2026-02-28' }, '2026-01-01', '2026-01-31');
    expect(cents).toBe(0n);
  });
});