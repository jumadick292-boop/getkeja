// Shared scheduling validation schemas (Task 13.9). Strict Zod.
import { z } from 'zod';

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/, 'HH:MM');
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'YYYY-MM-DD');

export const activityIdParamsSchema = z.object({ activityId: uuid });
export const rescheduleIdParamsSchema = z.object({ activityId: uuid, requestId: uuid });

export const domainEnum = z.enum(['moving', 'garbage', 'garbage_occurrence', 'laundry', 'home_maintenance', 'cleaning', 'installation']);

// Create/confirm a schedule for an existing operational resource.
export const createScheduleSchema = z
  .object({
    domain: domainEnum,
    resourceId: uuid,
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
    timeZone: z.string().trim().min(1).max(64).default('Africa/Nairobi'),
    allDay: z.boolean().default(false),
    locationId: uuid.optional().nullable(),
    address: z.string().trim().max(500).optional().nullable(),
    capacityKey: z.string().trim().max(64).optional(),
    staffUserId: uuid.optional().nullable(),
    reminderMinutesBefore: z.coerce.number().int().min(0).max(20160).optional(),
  })
  .strict()
  .refine((v) => new Date(v.endAt) > new Date(v.startAt), { message: 'endAt must be after startAt' });

export const updateScheduleWindowSchema = z
  .object({
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
    timeZone: z.string().trim().min(1).max(64).optional(),
  })
  .strict()
  .refine((v) => new Date(v.endAt) > new Date(v.startAt), { message: 'endAt must be after startAt' });

export const cancelScheduleSchema = z.object({ reason: z.string().trim().max(1000).optional() }).strict();

// Rescheduling.
export const requestRescheduleSchema = z
  .object({
    requestedStartAt: z.string().datetime(),
    requestedEndAt: z.string().datetime(),
    reason: z.string().trim().max(1000).optional(),
  })
  .strict()
  .refine((v) => new Date(v.requestedEndAt) > new Date(v.requestedStartAt), { message: 'end must be after start' });

export const decideRescheduleSchema = z.object({ accept: z.boolean() }).strict();

// Staff assignment.
export const assignStaffSchema = z
  .object({ userId: uuid, label: z.string().trim().max(120).optional() })
  .strict();
export const staffUserIdParamsSchema = z.object({ activityId: uuid, staffUserId: uuid });

// Availability / capacity.
export const staffAvailabilitySchema = z
  .object({
    dayOfWeek: z.coerce.number().int().min(0).max(6),
    openTime: time,
    closeTime: time,
    isAvailable: z.boolean().default(true),
    timeZone: z.string().trim().min(1).max(64).default('Africa/Nairobi'),
  })
  .strict();

export const staffLeaveSchema = z
  .object({
    startDate: date,
    endDate: date,
    reason: z.string().trim().max(1000).optional(),
  })
  .strict()
  .refine((v) => v.endDate >= v.startDate, { message: 'endDate must be on/after startDate' });

export const capacitySchema = z
  .object({
    providerProfileId: uuid,
    offeringId: uuid.optional().nullable(),
    capacityPerSlot: z.coerce.number().int().min(1).max(1000).default(1),
    slotMinutes: z.coerce.number().int().min(1).max(1440).default(60),
    bufferMinutes: z.coerce.number().int().min(0).max(1440).default(0),
    minNoticeMinutes: z.coerce.number().int().min(0).max(20160).default(0),
    maxAdvanceDays: z.coerce.number().int().min(1).max(3650).default(365),
    timeZone: z.string().trim().min(1).max(64).default('Africa/Nairobi'),
  })
  .strict();

// Calendar query (date-window bounded).
export const calendarQuerySchema = z.object({
  from: z.string().datetime(),
  to: z.string().datetime(),
  domains: z
    .union([domainEnum, z.array(domainEnum)])
    .transform((v) => (Array.isArray(v) ? v : [v]))
    .optional(),
  status: z.enum(['proposed', 'confirmed', 'cancelled', 'completed', 'missed']).optional(),
  staffUserId: uuid.optional(),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});

// Availability check.
export const availabilityCheckSchema = z
  .object({
    providerProfileId: uuid.optional(),
    staffUserId: uuid.optional(),
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
    timeZone: z.string().trim().min(1).max(64).default('Africa/Nairobi'),
  })
  .strict()
  .refine((v) => new Date(v.endAt) > new Date(v.startAt), { message: 'endAt must be after startAt' });

export type CreateScheduleInput = z.infer<typeof createScheduleSchema>;
export type RequestRescheduleInput = z.infer<typeof requestRescheduleSchema>;
export type AssignStaffInput = z.infer<typeof assignStaffSchema>;
export type CapacityInput = z.infer<typeof capacitySchema>;
export type AvailabilityCheckInput = z.infer<typeof availabilityCheckSchema>;