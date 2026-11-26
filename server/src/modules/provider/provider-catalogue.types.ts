// Provider service-catalogue domain types (Task 13.4).

export type ServiceDomain =
  | 'moving'
  | 'garbage'
  | 'laundry'
  | 'cleaning'
  | 'plumbing'
  | 'electrical'
  | 'hvac'
  | 'pest_control'
  | 'landscaping'
  | 'carpentry'
  | 'painting'
  | 'roofing'
  | 'flooring'
  | 'tiling'
  | 'appliances'
  | 'networking'
  | 'solar'
  | 'general';

export type OfferingStatus = 'draft' | 'active' | 'paused' | 'unavailable' | 'archived';

export type PricingModel =
  | 'fixed'
  | 'starting'
  | 'per_item'
  | 'per_unit'
  | 'per_km'
  | 'hourly'
  | 'weight'
  | 'volume'
  | 'custom_quote';

export interface ServiceCategory {
  id: string;
  domain: ServiceDomain;
  name: string;
  description: string | null;
  isActive: boolean;
  sortOrder: number;
}

export interface ServiceCapability {
  id: string;
  domain: ServiceDomain;
  name: string;
  description: string | null;
  isActive: boolean;
  sortOrder: number;
}

export interface OfferingCapability {
  id: string;
  capabilityId: string;
  name: string;
  enabled: boolean;
  detail: string | null;
}

export interface OfferingPricing {
  id: string;
  offeringId: string;
  pricingModel: PricingModel;
  currency: string;
  baseAmount: string | null;
  minimumCharge: string | null;
  unitLabel: string | null;
  quotationRequired: boolean;
  isIndicative: boolean;
  priceNotes: string | null;
}

export interface ProviderServiceOffering {
  id: string;
  specializedProfileId: string;
  domain: ServiceDomain;
  categoryId: string;
  categoryName: string;
  title: string;
  description: string | null;
  serviceType: string | null;
  status: OfferingStatus;
  config: Record<string, unknown>;
  temporaryUnavailableFrom: string | null;
  temporaryUnavailableTo: string | null;
  createdBy: string;
  updatedBy: string | null;
  createdAt: Date;
  updatedAt: Date;
  capabilities?: OfferingCapability[];
  pricing?: OfferingPricing | null;
}

export interface ProviderLocation {
  id: string;
  userId: string;
  specializedProfileId: string | null;
  organisationId: string | null;
  locationType: string;
  label: string | null;
  latitude: string;
  longitude: string;
  formattedAddress: string | null;
  placeId: string | null;
  country: string | null;
  county: string | null;
  city: string | null;
  neighbourhood: string | null;
  street: string | null;
  buildingName: string | null;
  locationSource: string;
  isPublic: boolean;
  visibility: string;
  isPrimary: boolean;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ProviderServiceArea {
  id: string;
  specializedProfileId: string;
  offeringId: string | null;
  country: string | null;
  county: string | null;
  city: string | null;
  neighbourhood: string | null;
  areaDescription: string | null;
  latitude: string | null;
  longitude: string | null;
  radiusKm: string | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ProviderOperatingHours {
  id: string;
  specializedProfileId: string | null;
  offeringId: string | null;
  dayOfWeek: number;
  openTime: string;
  closeTime: string;
  isClosed: boolean;
  timeZone: string;
}

export interface ProviderAvailabilityException {
  id: string;
  specializedProfileId: string;
  offeringId: string | null;
  exceptionDate: string;
  isUnavailable: boolean;
  startTime: string | null;
  endTime: string | null;
  reason: string | null;
  timeZone: string;
}