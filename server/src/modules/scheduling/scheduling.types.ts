// Shared scheduling domain types (Task 13.9).

export type SchedulingDomain = 'moving' | 'garbage' | 'garbage_occurrence' | 'laundry' | 'home_maintenance' | 'cleaning' | 'installation' | 'finishing';
export type SchedulingStatus = 'proposed' | 'confirmed' | 'cancelled' | 'completed' | 'missed';
export type RescheduleParty = 'customer' | 'provider';
export type RescheduleStatus = 'pending' | 'approved' | 'rejected' | 'cancelled';

export interface SchedulingActivity {
  id: string;
  domain: SchedulingDomain;
  resourceId: string;
  movingJobId: string | null;
  garbageJobId: string | null;
  garbageOccurrenceId: string | null;
  laundryOrderId: string | null;
  homeMaintenanceJobId: string | null;
  cleaningJobId: string | null;
  installationJobId: string | null;
  finishingJobId: string | null;
  startAt: string;
  endAt: string;
  timeZone: string;
  allDay: boolean;
  status: SchedulingStatus;
  locationId: string | null;
  address: string | null;
  customerUserId: string | null;
  providerProfileId: string | null;
  providerOrganisationId: string | null;
  assignedStaffUserId: string | null;
  capacityKey: string | null;
  reminderState: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface StaffAssignment {
  id: string;
  activityId: string;
  userId: string;
  providerOrganisationId: string | null;
  label: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: Date;
  revokedAt: string | null;
}

export interface RescheduleRequest {
  id: string;
  activityId: string;
  requestedBy: string;
  requestingParty: RescheduleParty;
  requestedStartAt: string;
  requestedEndAt: string;
  reason: string | null;
  status: RescheduleStatus;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: Date;
}

export interface StaffAvailability {
  id: string;
  userId: string;
  dayOfWeek: number;
  openTime: string;
  closeTime: string;
  isAvailable: boolean;
  timeZone: string;
}

export interface SchedulingCapacity {
  id: string;
  providerProfileId: string;
  offeringId: string | null;
  capacityPerSlot: number;
  slotMinutes: number;
  bufferMinutes: number;
  minNoticeMinutes: number;
  maxAdvanceDays: number;
  timeZone: string;
}

export interface CalendarFilters {
  from: string;
  to: string;
  domains?: SchedulingDomain[];
  status?: SchedulingStatus;
  staffUserId?: string;
  providerProfileId?: string;
  limit: number;
}