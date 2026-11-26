// Shared scheduling routes (Task 13.9) — mounted at /api/v1/scheduling.
import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  activityIdParamsSchema,
  rescheduleIdParamsSchema,
  staffUserIdParamsSchema,
  createScheduleSchema,
  cancelScheduleSchema,
  requestRescheduleSchema,
  decideRescheduleSchema,
  assignStaffSchema,
  staffAvailabilitySchema,
  staffLeaveSchema,
  capacitySchema,
  calendarQuerySchema,
  availabilityCheckSchema,
} from './scheduling.schemas.js';
import {
  providerCalendar,
  customerCalendar,
  getActivity,
  createSchedule,
  requestReschedule,
  decideReschedule,
  cancelSchedule,
  assignStaff,
  revokeStaff,
  checkAvailability,
  setStaffAvailability,
  addStaffLeave,
  setCapacity,
} from './scheduling.controller.js';

const setAvailabilitySchema = z.object({ days: z.array(staffAvailabilitySchema).min(1).max(7) }).strict();

export function createSchedulingRouter(): Router {
  const router = Router();
  router.use(requireAuth);

  // Calendars.
  router.get('/provider/calendar', validate(calendarQuerySchema, 'query'), providerCalendar);
  router.get('/customer/calendar', validate(calendarQuerySchema, 'query'), customerCalendar);
  router.get('/activities/:activityId', validate(activityIdParamsSchema, 'params'), getActivity);

  // Schedule lifecycle.
  router.post('/activities', validate(createScheduleSchema, 'body'), createSchedule);
  router.post('/activities/:activityId/reschedule', validate(activityIdParamsSchema, 'params'), validate(requestRescheduleSchema, 'body'), requestReschedule);
  router.post('/activities/:activityId/reschedule/:requestId/decide', validate(rescheduleIdParamsSchema, 'params'), validate(decideRescheduleSchema, 'body'), decideReschedule);
  router.post('/activities/:activityId/cancel', validate(activityIdParamsSchema, 'params'), validate(cancelScheduleSchema, 'body'), cancelSchedule);

  // Staff assignment.
  router.post('/activities/:activityId/staff', validate(activityIdParamsSchema, 'params'), validate(assignStaffSchema, 'body'), assignStaff);
  router.delete('/activities/:activityId/staff/:staffUserId', validate(staffUserIdParamsSchema, 'params'), revokeStaff);

  // Availability / capacity.
  router.post('/availability/check', validate(availabilityCheckSchema, 'body'), checkAvailability);
  router.put('/availability/staff', validate(setAvailabilitySchema, 'body'), setStaffAvailability);
  router.post('/availability/staff/leave', validate(staffLeaveSchema, 'body'), addStaffLeave);
  router.put('/capacity', validate(capacitySchema, 'body'), setCapacity);

  return router;
}