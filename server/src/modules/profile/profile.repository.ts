import type { PoolClient, QueryResultRow } from 'pg';
import { pool } from '../../db/pool.js';
import { ConflictError, ForbiddenError, ValidationError } from '../../shared/errors.js';
import type {
  CreateSpecializedProfileInput,
  LaundryServicesInput,
  OrganizationProfileInput,
  OrganizationReviewInput,
  PersonalProfileInput,
  ProfileCategory,
  ProfileReviewInput,
  ProviderExtensionInput,
  SavedLocationInput,
  ServiceAreaInput,
  UpdateServiceAreaInput,
  UpdateSpecializedProfileInput,
} from './profile.schema.js';

type ProfileRow = QueryResultRow & {
  id: string;
  user_id: string;
  profile_category: ProfileCategory;
  organisation_id: string | null;
  verification_status: string;
  full_name: string | null;
  display_name: string | null;
  business_name: string | null;
  description: string | null;
  contact_phone: string | null;
  contact_email: string | null;
  submitted_at: Date | null;
};

async function transaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function isUniqueViolation(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error &&
    (error as { code?: string }).code === '23505';
}

async function manageableProfile(
  client: PoolClient,
  profileId: string,
  userId: string,
): Promise<ProfileRow | null> {
  const result = await client.query<ProfileRow>(
    `SELECT sp.*
       FROM specialized_profiles sp
      WHERE sp.id = $1
        AND (
          sp.user_id = $2
          OR EXISTS (
            SELECT 1
              FROM organisation_members om
             WHERE om.organisation_id = sp.organisation_id
               AND om.user_id = $2
               AND om.status = 'active'
               AND om.role IN ('owner', 'admin')
          )
        )
      FOR UPDATE OF sp`,
    [profileId, userId],
  );
  return result.rows[0] ?? null;
}

async function reopenProfileForChanges(
  client: PoolClient,
  profile: ProfileRow,
): Promise<void> {
  if (profile.verification_status === 'suspended') {
    throw new ValidationError('Suspended profiles cannot be edited');
  }
  if (!['draft', 'incomplete'].includes(profile.verification_status)) {
    await client.query(
      `UPDATE specialized_profiles
          SET verification_status = 'draft', submitted_at = NULL,
              reviewed_at = NULL, reviewed_by = NULL, rejection_reason = NULL
        WHERE id = $1`,
      [profile.id],
    );
    await client.query(
      `INSERT INTO profile_verification_records
        (specialized_profile_id, previous_status, new_status, decision)
       VALUES ($1,$2,'draft','profile_updated')`,
      [profile.id, profile.verification_status],
    );
  }
}

async function isActiveOrganisationMember(
  client: PoolClient,
  userId: string,
  organisationId: string,
): Promise<boolean> {
  const result = await client.query(
    `SELECT 1 FROM organisation_members
      WHERE user_id = $1 AND organisation_id = $2 AND status = 'active'`,
    [userId, organisationId],
  );
  return result.rowCount !== 0;
}

export async function canUploadProfileImage(
  userId: string,
  input: { kind: 'personal_photo' } |
    { kind: 'profile_photo' | 'business_logo'; profileId: string } |
    { kind: 'organization_logo'; organizationId: string },
): Promise<boolean> {
  if (input.kind === 'personal_photo') return true;

  if (input.kind === 'organization_logo') {
    const result = await pool.query(
      `SELECT 1
         FROM organisation_members om
         JOIN organisations o ON o.id = om.organisation_id
        WHERE om.organisation_id = $1 AND om.user_id = $2
          AND om.status = 'active' AND om.role IN ('owner', 'admin')
        LIMIT 1`,
      [input.organizationId, userId],
    );
    return result.rowCount !== 0;
  }

  const result = await pool.query(
    `SELECT 1
       FROM specialized_profiles sp
      WHERE sp.id = $1
        AND (
          sp.user_id = $2
          OR EXISTS (
            SELECT 1 FROM organisation_members om
             WHERE om.organisation_id = sp.organisation_id
               AND om.user_id = $2 AND om.status = 'active'
               AND om.role IN ('owner', 'admin')
          )
        )
      LIMIT 1`,
    [input.profileId, userId],
  );
  return result.rowCount !== 0;
}

async function hasProfileCategoryRole(
  client: PoolClient,
  userId: string,
  category: ProfileCategory,
  organisationId?: string | null,
): Promise<boolean> {
  if (category === 'agency') {
    if (!organisationId) return false;
    const result = await client.query(
      `SELECT 1
         FROM organisations o
         JOIN organisation_members om ON om.organisation_id = o.id
        WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'
          AND om.role IN ('owner', 'admin')
          AND o.type IN ('letting_agency', 'real_estate_agency', 'agency')
        LIMIT 1`,
      [organisationId, userId],
    );
    return result.rowCount !== 0;
  }

  const roleIds: Record<Exclude<ProfileCategory, 'agency'>, string[]> = {
    house_seeker: ['house_seeker'],
    tenant: ['tenant'],
    landlord: ['landlord'],
    real_estate_agent: ['letting_agent', 'real_estate_agent'],
    property_manager: ['property_manager'],
    caretaker: ['caretaker'],
    moving_service_provider: ['moving_company', 'individual_mover', 'service_provider'],
    garbage_collection_provider: ['garbage_provider', 'service_provider'],
    laundry_service_provider: ['laundry_provider', 'service_provider'],
  };
  const result = await client.query(
    `SELECT 1
       WHERE EXISTS (
         SELECT 1 FROM user_roles ur
          WHERE ur.user_id = $1 AND ur.role_id = ANY($2::varchar[])
       )
          OR EXISTS (
         SELECT 1 FROM role_assignments ra
          WHERE ra.user_id = $1
            AND ra.role_id = ANY($2::varchar[])
            AND ra.revoked_at IS NULL
            AND (ra.expires_at IS NULL OR ra.expires_at > NOW())
            AND (
              ra.scope = 'global'
              OR (ra.scope = 'organization' AND ra.organization_id = $3)
            )
       )`,
    [userId, roleIds[category], organisationId ?? null],
  );
  return result.rowCount !== 0;
}

async function writeProfileAudit(
  client: PoolClient,
  userId: string,
  action: string,
  profile: ProfileRow,
  details: Record<string, unknown> = {},
): Promise<void> {
  await client.query(
    `INSERT INTO authorization_audit
      (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
     VALUES ($1,'allow',$2,'specialized_profile',$3,$4,$5)`,
    [
      userId, `profile.${action}`, profile.id, profile.organisation_id,
      JSON.stringify(details),
    ],
  );
}

function categoryFields(category: ProfileCategory): string[] {
  switch (category) {
    case 'house_seeker':
    case 'tenant':
    case 'real_estate_agent':
    case 'caretaker':
      return ['fullName'];
    case 'landlord':
      return ['fullName or businessName'];
    case 'agency':
      return ['businessName', 'description', 'contactEmail'];
    case 'property_manager':
      return ['fullName or businessName', 'description', 'contactPhone'];
    case 'moving_service_provider':
    case 'garbage_collection_provider':
      return [
        'fullName or businessName', 'description', 'contactPhone',
        'serviceTypes', 'serviceDescription', 'serviceAreas',
      ];
    case 'laundry_service_provider':
      return [
        'fullName or businessName', 'description', 'contactPhone',
        'serviceDescription', 'laundryServices', 'serviceAreas',
      ];
  }
}

async function calculateCompletion(client: PoolClient, profile: ProfileRow) {
  const requirements = categoryFields(profile.profile_category);
  const missing: string[] = [];
  for (const field of requirements) {
    if (field === 'fullName' && !profile.full_name?.trim()) missing.push(field);
    else if (field === 'businessName' && !profile.business_name?.trim()) missing.push(field);
    else if (field === 'fullName or businessName' &&
      !profile.full_name?.trim() && !profile.business_name?.trim()) missing.push(field);
    else if (field === 'description' && !profile.description?.trim()) missing.push(field);
    else if (field === 'contactEmail' && !profile.contact_email?.trim()) missing.push(field);
    else if (field === 'contactPhone' && !profile.contact_phone?.trim()) missing.push(field);
  }

  if (requirements.includes('serviceTypes')) {
    const extension = await client.query<{
      service_types: string[];
      service_description: string | null;
    }>(
      `SELECT service_types, service_description
         FROM provider_profile_extensions WHERE specialized_profile_id = $1`,
      [profile.id],
    );
    if (!extension.rows[0]?.service_types?.length) missing.push('serviceTypes');
    if (!extension.rows[0]?.service_description?.trim()) missing.push('serviceDescription');
  }
  if (requirements.includes('serviceDescription') &&
      !requirements.includes('serviceTypes')) {
    const extension = await client.query<{ service_description: string | null }>(
      `SELECT service_description
         FROM provider_profile_extensions WHERE specialized_profile_id = $1`,
      [profile.id],
    );
    if (!extension.rows[0]?.service_description?.trim()) missing.push('serviceDescription');
  }
  if (requirements.includes('serviceAreas')) {
    const areas = await client.query(
      `SELECT 1 FROM provider_service_areas
        WHERE specialized_profile_id = $1 AND is_active = TRUE LIMIT 1`,
      [profile.id],
    );
    if (!areas.rowCount) missing.push('serviceAreas');
  }
  if (requirements.includes('laundryServices')) {
    const services = await client.query<{ offers_any_service: boolean }>(
      `SELECT (
         offers_washing OR offers_dry_cleaning OR offers_ironing OR offers_folding OR
         offers_bedding_cleaning OR offers_household_textile_cleaning OR offers_other_services
       ) AS offers_any_service
         FROM laundry_provider_services lps
         JOIN provider_profile_extensions ppe ON ppe.id = lps.provider_profile_id
        WHERE ppe.specialized_profile_id = $1`,
      [profile.id],
    );
    if (!services.rows[0]?.offers_any_service) missing.push('laundryServices');
  }

  const percentage = requirements.length === 0
    ? 100
    : Math.round(((requirements.length - missing.length) / requirements.length) * 100);
  const submitted = ['submitted', 'pending_review', 'approved'].includes(profile.verification_status);
  const existing = await client.query<{ id: string }>(
    `SELECT id FROM profile_completion_metadata
      WHERE specialized_profile_id = $1
      ORDER BY updated_at DESC LIMIT 1 FOR UPDATE`,
    [profile.id],
  );
  const metadataValues = [
    requirements.length,
    requirements.length - missing.length,
    percentage,
    JSON.stringify(missing),
    submitted,
    profile.submitted_at ?? null,
    missing.length === 0,
  ];
  const returning = `RETURNING id, specialized_profile_id AS "specializedProfileId",
       total_required_fields AS "totalRequiredFields",
       completed_fields AS "completedFields",
       completion_percentage AS "completionPercentage",
       missing_fields AS "missingFields", is_submitted AS "isSubmitted",
       submitted_at AS "submittedAt", can_submit AS "canSubmit",
       created_at AS "createdAt", updated_at AS "updatedAt"`;
  const result = existing.rows[0]
    ? await client.query(
        `UPDATE profile_completion_metadata SET
           total_required_fields = $1, completed_fields = $2,
           completion_percentage = $3, missing_fields = $4,
           is_submitted = $5, submitted_at = $6, can_submit = $7, updated_at = NOW()
         WHERE id = $8 ${returning}`,
        [...metadataValues, existing.rows[0].id],
      )
    : await client.query(
        `INSERT INTO profile_completion_metadata
          (specialized_profile_id, total_required_fields, completed_fields,
           completion_percentage, missing_fields, is_submitted, submitted_at, can_submit)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ${returning}`,
        [profile.id, ...metadataValues],
      );
  await client.query(
    `UPDATE specialized_profiles
        SET completion_percentage = $1, missing_fields = $2
      WHERE id = $3`,
    [percentage, JSON.stringify(missing), profile.id],
  );
  return {
    ...result.rows[0],
    completionPercentage: percentage,
    missingFields: missing,
  };
}

async function refreshCompletion(client: PoolClient, profileId: string): Promise<void> {
  const result = await client.query<ProfileRow>(
    'SELECT * FROM specialized_profiles WHERE id = $1',
    [profileId],
  );
  if (result.rows[0]) await calculateCompletion(client, result.rows[0]);
}

export async function getOrCreatePersonalProfile(userId: string) {
  await pool.query(
    'INSERT INTO user_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING',
    [userId],
  );
  const result = await pool.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
  return result.rows[0];
}

export async function updatePersonalProfile(userId: string, data: PersonalProfileInput) {
  const columns = {
    displayName: 'display_name',
    profilePhotoUrl: 'profile_photo_url',
    bio: 'bio',
    phoneNumber: 'phone_number',
    websiteUrl: 'website_url',
  } as const;
  return transaction(async (client) => {
    await client.query(
      `INSERT INTO user_profiles (user_id) VALUES ($1)
       ON CONFLICT (user_id) DO NOTHING`,
      [userId],
    );
    const entries = Object.entries(data).filter(([key]) => key in columns);
    if (!entries.length) {
      const current = await client.query('SELECT * FROM user_profiles WHERE user_id = $1', [userId]);
      return current.rows[0];
    }
    const values: unknown[] = [];
    const setters = entries.map(([key, value], index) => {
      values.push(value);
      return `${columns[key as keyof typeof columns]} = $${index + 1}`;
    });
    values.push(userId);
    const result = await client.query(
      `UPDATE user_profiles SET ${setters.join(', ')}, updated_at = NOW()
        WHERE user_id = $${values.length} RETURNING *`,
      values,
    );
    return result.rows[0];
  });
}

export async function listSpecializedProfiles(userId: string) {
  return transaction(async (client) => {
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
    const result = await client.query<ProfileRow>(
      `SELECT sp.* FROM specialized_profiles sp
        WHERE sp.user_id = $1
           OR EXISTS (
             SELECT 1 FROM organisation_members om
              WHERE om.organisation_id = sp.organisation_id
                AND om.user_id = $1 AND om.status = 'active'
                AND om.role IN ('owner', 'admin')
           )
        ORDER BY sp.created_at DESC
        FOR UPDATE OF sp`,
      [userId],
    );
    const profiles = [];
    for (const profile of result.rows) {
      const completion = await calculateCompletion(client, profile) as {
        completionPercentage: number;
        missingFields: string[];
      };
      profiles.push({
        ...profile,
        completionPercentage: completion.completionPercentage,
        missingFields: completion.missingFields,
        completion,
      });
    }
    return profiles;
  });
}

export async function createSpecializedProfile(userId: string, data: CreateSpecializedProfileInput) {
  try {
    return await transaction(async (client) => {
      await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
      if (!await hasProfileCategoryRole(
        client,
        userId,
        data.profileCategory,
        data.organisationId,
      )) {
        throw new ForbiddenError('An assigned role or authorized organization membership is required for this profile type');
      }
      if (data.organisationId &&
          !await isActiveOrganisationMember(client, userId, data.organisationId)) {
        return null;
      }
      const duplicate = await client.query(
        `SELECT id FROM specialized_profiles
          WHERE user_id = $1 AND profile_category = $2
            AND organisation_id IS NOT DISTINCT FROM $3`,
        [userId, data.profileCategory, data.organisationId ?? null],
      );
      if (duplicate.rowCount) throw new ConflictError('This profile category already exists');
      const result = await client.query(
        `INSERT INTO specialized_profiles
          (user_id, profile_category, full_name, display_name, profile_photo_url,
           business_name, business_logo_url, description, contact_email, contact_phone,
           website_url, organisation_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
         RETURNING *`,
        [
          userId, data.profileCategory, data.fullName ?? null, data.displayName ?? null,
          data.profilePhotoUrl ?? null, data.businessName ?? null, data.businessLogoUrl ?? null,
          data.description ?? null, data.contactEmail ?? null, data.contactPhone ?? null,
          data.websiteUrl ?? null, data.organisationId ?? null,
        ],
      );
      await refreshCompletion(client, result.rows[0].id);
      await writeProfileAudit(client, userId, 'create', {
        ...result.rows[0],
        organisation_id: data.organisationId ?? null,
      });
      return result.rows[0];
    });
  } catch (error) {
    if (isUniqueViolation(error)) throw new ConflictError('This profile category already exists');
    throw error;
  }
}

export async function getSpecializedProfile(id: string, userId: string) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, id, userId);
    if (!profile) return null;
    const completion = await calculateCompletion(client, profile);
    return { ...profile, completion };
  });
}

export async function updateSpecializedProfile(
  id: string,
  userId: string,
  data: UpdateSpecializedProfileInput,
) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, id, userId);
    if (!profile) return null;
    if (data.organisationId &&
        !await isActiveOrganisationMember(client, userId, data.organisationId)) {
      return null;
    }
    const columns = {
      fullName: 'full_name',
      displayName: 'display_name',
      profilePhotoUrl: 'profile_photo_url',
      businessName: 'business_name',
      businessLogoUrl: 'business_logo_url',
      description: 'description',
      contactEmail: 'contact_email',
      contactPhone: 'contact_phone',
      websiteUrl: 'website_url',
      organisationId: 'organisation_id',
    } as const;
    const entries = Object.entries(data).filter(([key]) => key in columns);
    if (!entries.length) return profile;
    await reopenProfileForChanges(client, profile);
    const values: unknown[] = [];
    const setters = entries.map(([key, value], index) => {
      values.push(value);
      return `${columns[key as keyof typeof columns]} = $${index + 1}`;
    });
    values.push(id);
    const result = await client.query<ProfileRow>(
      `UPDATE specialized_profiles SET ${setters.join(', ')}, updated_at = NOW()
        WHERE id = $${values.length} RETURNING *`,
      values,
    );
    const updatedProfile = result.rows[0];
    if (!updatedProfile) return null;
    const completion = await calculateCompletion(client, updatedProfile) as {
      completionPercentage: number;
      missingFields: string[];
    };
    await writeProfileAudit(client, userId, 'update', updatedProfile, {
      updatedFields: entries.map(([key]) => key),
    });
    return {
      ...updatedProfile,
      completionPercentage: completion.completionPercentage,
      missingFields: completion.missingFields,
      completion,
    };
  });
}

export async function getCompletionMetadata(profileId: string, userId: string) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, profileId, userId);
    return profile ? calculateCompletion(client, profile) : null;
  });
}

export async function submitProfile(profileId: string, userId: string) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, profileId, userId);
    if (!profile) return null;
    if (['approved', 'suspended'].includes(profile.verification_status)) {
      throw new ValidationError('This profile cannot be submitted in its current state');
    }
    const completion = await calculateCompletion(client, profile) as {
      canSubmit: boolean;
      missingFields: string[];
    };
    if (!completion.canSubmit) {
      throw new ValidationError(`Complete required fields before submitting: ${completion.missingFields.join(', ')}`);
    }
    const result = await client.query(
      `UPDATE specialized_profiles
          SET verification_status = 'submitted', submitted_at = NOW(), updated_at = NOW()
        WHERE id = $1 RETURNING *`,
      [profileId],
    );
    const documents = await client.query(
      `SELECT id, document_type AS "documentType", created_at AS "uploadedAt"
         FROM profile_verification_documents
        WHERE specialized_profile_id = $1 AND status = 'submitted' ORDER BY created_at`,
      [profileId],
    );
    await client.query(
      `INSERT INTO profile_verification_records
        (specialized_profile_id, previous_status, new_status, decision, submitted_at,
         documents_submitted)
       VALUES ($1,$2,'submitted','submitted',NOW(),$3)`,
      [profileId, profile.verification_status, JSON.stringify(documents.rows)],
    );
    await writeProfileAudit(client, userId, 'submit', profile, {
      previousStatus: profile.verification_status,
    });
    await calculateCompletion(client, result.rows[0]);
    return result.rows[0];
  });
}

export async function getProviderExtension(profileId: string, userId: string) {
  const result = await pool.query(
    `SELECT ppe.* FROM provider_profile_extensions ppe
      JOIN specialized_profiles sp ON sp.id = ppe.specialized_profile_id
     WHERE sp.id = $1
       AND sp.profile_category IN (
         'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider'
       )
       AND (sp.user_id = $2 OR EXISTS (
         SELECT 1 FROM organisation_members om
          WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
            AND om.status = 'active' AND om.role IN ('owner', 'admin')
       ))`,
    [profileId, userId],
  );
  return result.rows[0] ?? null;
}

export async function upsertProviderExtension(
  profileId: string,
  userId: string,
  data: ProviderExtensionInput,
) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, profileId, userId);
    if (!profile || ![
      'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider',
    ].includes(profile.profile_category)) return null;
    if (Object.keys(data).length > 0) await reopenProfileForChanges(client, profile);
    const existing = await client.query(
      'SELECT id FROM provider_profile_extensions WHERE specialized_profile_id = $1',
      [profileId],
    );
    const record = existing.rows[0]
      ? await updateProviderExtension(client, profileId, data)
      : await insertProviderExtension(client, profileId, data);
    await refreshCompletion(client, profileId);
    await writeProfileAudit(client, userId, 'provider_update', profile, {
      updatedFields: Object.keys(data),
    });
    return record;
  });
}

async function insertProviderExtension(
  client: PoolClient,
  profileId: string,
  data: ProviderExtensionInput,
) {
  const result = await client.query(
    `INSERT INTO provider_profile_extensions
      (specialized_profile_id, service_types, service_description, operating_status,
       registration_number, tax_id, business_hours, available_24_7, emergency_service,
       insurance_info, certifications, booking_contact_email, booking_contact_phone)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
    [
      profileId, JSON.stringify(data.serviceTypes ?? []), data.serviceDescription ?? null,
      data.operatingStatus ?? 'active', data.registrationNumber ?? null, data.taxId ?? null,
      data.businessHours ? JSON.stringify(data.businessHours) : null, data.available247 ?? false,
      data.emergencyService ?? false, data.insuranceInfo ? JSON.stringify(data.insuranceInfo) : null,
      JSON.stringify(data.certifications ?? []), data.bookingContactEmail ?? null,
      data.bookingContactPhone ?? null,
    ],
  );
  return result.rows[0];
}

async function updateProviderExtension(
  client: PoolClient,
  profileId: string,
  data: ProviderExtensionInput,
) {
  const columns = {
    serviceTypes: 'service_types',
    serviceDescription: 'service_description',
    operatingStatus: 'operating_status',
    registrationNumber: 'registration_number',
    taxId: 'tax_id',
    businessHours: 'business_hours',
    available247: 'available_24_7',
    emergencyService: 'emergency_service',
    insuranceInfo: 'insurance_info',
    certifications: 'certifications',
    bookingContactEmail: 'booking_contact_email',
    bookingContactPhone: 'booking_contact_phone',
  } as const;
  const entries = Object.entries(data).filter(([key]) => key in columns);
  if (!entries.length) {
    const result = await client.query(
      'SELECT * FROM provider_profile_extensions WHERE specialized_profile_id = $1',
      [profileId],
    );
    return result.rows[0] ?? null;
  }
  const values: unknown[] = [];
  const setters = entries.map(([key, value], index) => {
    const serialized = ['serviceTypes', 'businessHours', 'insuranceInfo', 'certifications'].includes(key)
      ? JSON.stringify(value)
      : value;
    values.push(serialized);
    return `${columns[key as keyof typeof columns]} = $${index + 1}`;
  });
  values.push(profileId);
  const result = await client.query(
    `UPDATE provider_profile_extensions SET ${setters.join(', ')}, updated_at = NOW()
      WHERE specialized_profile_id = $${values.length} RETURNING *`,
    values,
  );
  return result.rows[0] ?? null;
}

export async function getLaundryServices(extensionId: string, userId: string) {
  const result = await pool.query(
    `SELECT lps.* FROM laundry_provider_services lps
      JOIN provider_profile_extensions ppe ON ppe.id = lps.provider_profile_id
      JOIN specialized_profiles sp ON sp.id = ppe.specialized_profile_id
     WHERE ppe.id = $1 AND sp.profile_category = 'laundry_service_provider'
       AND (sp.user_id = $2 OR EXISTS (
         SELECT 1 FROM organisation_members om
          WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
            AND om.status = 'active' AND om.role IN ('owner', 'admin')
       ))
       FOR UPDATE OF sp`,
    [extensionId, userId],
  );
  return result.rows[0] ?? null;
}

export async function upsertLaundryServices(
  extensionId: string,
  userId: string,
  data: LaundryServicesInput,
) {
  return transaction(async (client) => {
    const profileResult = await client.query<ProfileRow>(
      `SELECT sp.* FROM specialized_profiles sp
        JOIN provider_profile_extensions ppe ON ppe.specialized_profile_id = sp.id
       WHERE ppe.id = $1 AND sp.profile_category = 'laundry_service_provider'
         AND (sp.user_id = $2 OR EXISTS (
           SELECT 1 FROM organisation_members om
            WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
              AND om.status = 'active' AND om.role IN ('owner', 'admin')
         ))`,
      [extensionId, userId],
    );
    const profile = profileResult.rows[0];
    if (!profile) return null;
    if (Object.keys(data).length > 0) await reopenProfileForChanges(client, profile);
    const columns = {
      offersWashing: 'offers_washing',
      offersDryCleaning: 'offers_dry_cleaning',
      offersIroning: 'offers_ironing',
      offersFolding: 'offers_folding',
      offersBeddingCleaning: 'offers_bedding_cleaning',
      offersHouseholdTextileCleaning: 'offers_household_textile_cleaning',
      offersOtherServices: 'offers_other_services',
      otherServicesDescription: 'other_services_description',
      specialHandlingInfo: 'special_handling_info',
      offersPickup: 'offers_pickup',
      offersDelivery: 'offers_delivery',
      customerVisitRequired: 'customer_visit_required',
      pickupDeliveryAreas: 'pickup_delivery_areas',
    } as const;
    const existing = await client.query(
      'SELECT id FROM laundry_provider_services WHERE provider_profile_id = $1',
      [extensionId],
    );
    let result;
    if (existing.rows[0]) {
      const entries = Object.entries(data).filter(([key]) => key in columns);
      if (!entries.length) {
        result = await client.query(
          'SELECT * FROM laundry_provider_services WHERE provider_profile_id = $1',
          [extensionId],
        );
      } else {
        const values: unknown[] = [];
        const setters = entries.map(([key, value], index) => {
          values.push(key === 'pickupDeliveryAreas' ? JSON.stringify(value) : value);
          return `${columns[key as keyof typeof columns]} = $${index + 1}`;
        });
        values.push(extensionId);
        result = await client.query(
          `UPDATE laundry_provider_services SET ${setters.join(', ')}, updated_at = NOW()
            WHERE provider_profile_id = $${values.length} RETURNING *`,
          values,
        );
      }
    } else {
      result = await client.query(
        `INSERT INTO laundry_provider_services
          (provider_profile_id, offers_washing, offers_dry_cleaning, offers_ironing,
           offers_folding, offers_bedding_cleaning, offers_household_textile_cleaning,
           offers_other_services, other_services_description, special_handling_info,
           offers_pickup, offers_delivery, customer_visit_required, pickup_delivery_areas)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING *`,
        [
          extensionId, data.offersWashing ?? false, data.offersDryCleaning ?? false,
          data.offersIroning ?? false, data.offersFolding ?? false,
          data.offersBeddingCleaning ?? false, data.offersHouseholdTextileCleaning ?? false,
          data.offersOtherServices ?? false, data.otherServicesDescription ?? null,
          data.specialHandlingInfo ?? null, data.offersPickup ?? false,
          data.offersDelivery ?? false, data.customerVisitRequired ?? false,
          JSON.stringify(data.pickupDeliveryAreas ?? []),
        ],
      );
    }
    await refreshCompletion(client, profile.id);
    await writeProfileAudit(client, userId, 'laundry_services_update', profile, {
      updatedFields: Object.keys(data),
    });
    return result.rows[0] ?? null;
  });
}

export async function saveLocation(userId: string, data: SavedLocationInput) {
  return transaction(async (client) => {
    let profile: ProfileRow | null = null;
    if (data.specializedProfileId) {
      profile = await manageableProfile(client, data.specializedProfileId, userId);
      if (!profile) return null;
      await reopenProfileForChanges(client, profile);
      const businessCategories = ['agency', 'landlord', 'property_manager', 'real_estate_agent'];
      const providerCategories = [
        'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider',
      ];
      const permitted = data.locationType === 'business_office'
        ? businessCategories.includes(profile.profile_category)
        : providerCategories.includes(profile.profile_category);
      if (!permitted) return null;
    }
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
    const existing = await client.query(
      `SELECT id FROM saved_locations
        WHERE user_id = $1 AND location_type = $2
          AND specialized_profile_id IS NOT DISTINCT FROM $3`,
      [userId, data.locationType, data.specializedProfileId ?? null],
    );
    const values = [
      data.latitude, data.longitude, data.formattedAddress ?? null, data.placeId ?? null,
      data.country ?? null, data.county ?? null, data.city ?? null, data.neighborhood ?? null,
      data.street ?? null, data.buildingName ?? null, data.locationSource,
      data.accuracy ?? null,
    ];
    if (existing.rows[0]) {
      const result = await client.query(
        `UPDATE saved_locations SET latitude = $1, longitude = $2, formatted_address = $3,
           place_id = $4, country = $5, county = $6, city = $7, neighbourhood = $8,
           street = $9, building_name = $10, location_source = $11, accuracy_meters = $12,
           is_confirmed = TRUE, confirmed_at = NOW(), updated_at = NOW()
         WHERE id = $13 AND user_id = $14 RETURNING *`,
        [...values, existing.rows[0].id, userId],
      );
      await client.query(
        `INSERT INTO authorization_audit
          (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
         VALUES ($1,'allow','profile.location.update','saved_location',$2,$3,$4)`,
        [
          userId, result.rows[0].id, profile?.organisation_id ?? null,
          JSON.stringify({ locationType: data.locationType }),
        ],
      );
      if (profile) await refreshCompletion(client, profile.id);
      return result.rows[0];
    }
    const result = await client.query(
      `INSERT INTO saved_locations
        (user_id, specialized_profile_id, location_type, latitude, longitude,
         formatted_address, place_id, country, county, city, neighbourhood,
         street, building_name, location_source, accuracy_meters, is_confirmed, confirmed_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,TRUE,NOW())
       RETURNING *`,
      [
        userId, data.specializedProfileId ?? null, data.locationType,
        ...values,
      ],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','profile.location.create','saved_location',$2,$3,$4)`,
      [
        userId, result.rows[0].id, profile?.organisation_id ?? null,
        JSON.stringify({ locationType: data.locationType }),
      ],
    );
    if (profile) await refreshCompletion(client, profile.id);
    return result.rows[0];
  });
}

export async function getLocations(userId: string, profileId?: string) {
  if (profileId) {
    const access = await pool.query(
      `SELECT 1 FROM specialized_profiles sp
        WHERE sp.id = $1 AND (
          sp.user_id = $2 OR EXISTS (
            SELECT 1 FROM organisation_members om
             WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
               AND om.status = 'active' AND om.role IN ('owner', 'admin')
          )
        )`,
      [profileId, userId],
    );
    if (!access.rowCount) return null;
  }
  const result = await pool.query(
    `SELECT * FROM saved_locations
      WHERE user_id = $1
        AND ($2::uuid IS NULL OR specialized_profile_id = $2)
      ORDER BY updated_at DESC`,
    [userId, profileId ?? null],
  );
  return result.rows;
}

export async function addServiceArea(userId: string, data: ServiceAreaInput) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, data.profileId, userId);
    if (!profile || ![
      'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider',
    ].includes(profile.profile_category)) return null;
    await reopenProfileForChanges(client, profile);
    const result = await client.query(
      `INSERT INTO provider_service_areas
        (specialized_profile_id, country, county, city, neighbourhood,
         area_description, latitude, longitude, radius_km, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [
        data.profileId, data.country ?? null, data.county ?? null, data.city ?? null,
        data.neighborhood ?? null, data.areaDescription ?? null, data.latitude ?? null,
        data.longitude ?? null, data.radiusKm ?? null, data.status === 'active',
      ],
    );
    await refreshCompletion(client, data.profileId);
    await writeProfileAudit(client, userId, 'service_area_create', profile, {
      serviceAreaId: result.rows[0].id,
    });
    return result.rows[0];
  });
}

export async function listServiceAreas(profileId: string, userId: string) {
  const access = await pool.query(
    `SELECT 1 FROM specialized_profiles sp
      WHERE sp.id = $1 AND sp.profile_category IN (
        'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider'
      ) AND (
        sp.user_id = $2 OR EXISTS (
          SELECT 1 FROM organisation_members om
           WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
             AND om.status = 'active' AND om.role IN ('owner', 'admin')
        )
      )`,
    [profileId, userId],
  );
  if (!access.rowCount) return null;
  const result = await pool.query(
    `SELECT id, specialized_profile_id AS "profileId", country, county, city,
            neighbourhood AS neighborhood, area_description AS "areaDescription",
            latitude, longitude, radius_km AS "radiusKm", is_active AS "isActive",
            created_at AS "createdAt", updated_at AS "updatedAt"
       FROM provider_service_areas WHERE specialized_profile_id = $1 ORDER BY created_at`,
    [profileId],
  );
  return result.rows;
}

export async function updateServiceArea(
  areaId: string,
  userId: string,
  data: UpdateServiceAreaInput,
) {
  return transaction(async (client) => {
    const owned = await client.query<{
      specialized_profile_id: string;
      profile_category: string;
      latitude: string | number | null;
      longitude: string | number | null;
      radius_km: string | number | null;
    }>(
      `SELECT psa.specialized_profile_id, psa.latitude, psa.longitude, psa.radius_km,
              sp.profile_category
         FROM provider_service_areas psa
        JOIN specialized_profiles sp ON sp.id = psa.specialized_profile_id
       WHERE psa.id = $1 AND (
         sp.user_id = $2 OR EXISTS (
           SELECT 1 FROM organisation_members om
            WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
              AND om.status = 'active' AND om.role IN ('owner', 'admin')
         )
       )`,
      [areaId, userId],
    );
    const area = owned.rows[0];
    const profileId = area?.specialized_profile_id;
    if (!profileId) return null;
    if (![
      'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider',
    ].includes(area.profile_category)) return null;
    const latitude = data.latitude === undefined ? area.latitude : data.latitude;
    const longitude = data.longitude === undefined ? area.longitude : data.longitude;
    const radiusKm = data.radiusKm === undefined ? area.radius_km : data.radiusKm;
    if ((latitude === null) !== (longitude === null)) {
      throw new ValidationError('Latitude and longitude must be provided together');
    }
    if (radiusKm !== null && (latitude === null || longitude === null)) {
      throw new ValidationError('A service-area radius requires center coordinates');
    }
    const profile = await client.query<ProfileRow>(
      'SELECT * FROM specialized_profiles WHERE id = $1 FOR UPDATE',
      [profileId],
    );
    if (profile.rows[0]) await reopenProfileForChanges(client, profile.rows[0]);
    const columns = {
      country: 'country',
      county: 'county',
      city: 'city',
      neighborhood: 'neighbourhood',
      areaDescription: 'area_description',
      latitude: 'latitude',
      longitude: 'longitude',
      radiusKm: 'radius_km',
    } as const;
    const entries = Object.entries(data).filter(([key]) => key in columns);
    const values: unknown[] = [];
    const setters = entries.map(([key, value], index) => {
      values.push(value);
      return `${columns[key as keyof typeof columns]} = $${index + 1}`;
    });
    if (data.status !== undefined) {
      values.push(data.status === 'active');
      setters.push(`is_active = $${values.length}`);
    }
    if (!setters.length) {
      const current = await client.query(
        'SELECT * FROM provider_service_areas WHERE id = $1',
        [areaId],
      );
      return current.rows[0] ?? null;
    }
    if (profile.rows[0]) await reopenProfileForChanges(client, profile.rows[0]);
    values.push(areaId);
    const result = await client.query(
      `UPDATE provider_service_areas SET ${setters.join(', ')}, updated_at = NOW()
        WHERE id = $${values.length} RETURNING *`,
      values,
    );
    await refreshCompletion(client, profileId);
    const updatedProfile = await client.query<ProfileRow>(
      'SELECT * FROM specialized_profiles WHERE id = $1',
      [profileId],
    );
    if (updatedProfile.rows[0]) {
      await writeProfileAudit(client, userId, 'service_area_update', updatedProfile.rows[0], {
        serviceAreaId: areaId,
        updatedFields: Object.keys(data),
      });
    }
    return result.rows[0] ?? null;
  });
}

export async function deleteServiceArea(areaId: string, userId: string) {
  return transaction(async (client) => {
    const result = await client.query<{ specialized_profile_id: string }>(
      `DELETE FROM provider_service_areas psa
        USING specialized_profiles sp
       WHERE psa.id = $1 AND sp.id = psa.specialized_profile_id
          AND sp.profile_category IN (
            'moving_service_provider', 'garbage_collection_provider', 'laundry_service_provider'
          )
         AND (
           sp.user_id = $2 OR EXISTS (
             SELECT 1 FROM organisation_members om
              WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
                AND om.status = 'active' AND om.role IN ('owner', 'admin')
           )
         )
       RETURNING psa.specialized_profile_id`,
      [areaId, userId],
    );
    const profileId = result.rows[0]?.specialized_profile_id;
    if (!profileId) return false;
    const profile = await client.query<ProfileRow>(
      'SELECT * FROM specialized_profiles WHERE id = $1 FOR UPDATE',
      [profileId],
    );
    if (profile.rows[0]) await reopenProfileForChanges(client, profile.rows[0]);
    await refreshCompletion(client, profileId);
    if (profile.rows[0]) {
      await writeProfileAudit(client, userId, 'service_area_delete', profile.rows[0], {
        serviceAreaId: areaId,
      });
    }
    return true;
  });
}

export async function listVerificationRecords(profileId: string, userId: string) {
  const access = await pool.query(
    `SELECT 1 FROM specialized_profiles sp
      WHERE sp.id = $1 AND (
        sp.user_id = $2 OR EXISTS (
          SELECT 1 FROM organisation_members om
           WHERE om.organisation_id = sp.organisation_id AND om.user_id = $2
             AND om.status = 'active' AND om.role IN ('owner', 'admin')
        )
      )`,
    [profileId, userId],
  );
  if (!access.rowCount) return null;
  const result = await pool.query(
    `SELECT id, specialized_profile_id AS "specializedProfileId",
            previous_status AS "previousStatus", new_status AS "newStatus",
            decision, rejection_reason AS "rejectionReason",
            requested_changes AS "requestedChanges", submitted_at AS "submittedAt",
            reviewed_at AS "reviewedAt", created_at AS "createdAt"
       FROM profile_verification_records
      WHERE specialized_profile_id = $1 ORDER BY created_at DESC`,
    [profileId],
  );
  return result.rows;
}

export async function listProfilesForReview() {
  const result = await pool.query(
    `SELECT sp.id, sp.profile_category AS "profileCategory", sp.full_name AS "fullName",
            sp.display_name AS "displayName", sp.business_name AS "businessName",
            sp.description, sp.contact_email AS "contactEmail",
            sp.contact_phone AS "contactPhone", sp.organisation_id AS "organisationId",
            sp.verification_status AS "verificationStatus", sp.submitted_at AS "submittedAt",
            pcm.completion_percentage AS "completionPercentage",
            pcm.missing_fields AS "missingFields"
       FROM specialized_profiles sp
       LEFT JOIN profile_completion_metadata pcm ON pcm.specialized_profile_id = sp.id
      WHERE sp.verification_status IN ('submitted', 'pending_review')
      ORDER BY sp.submitted_at ASC NULLS LAST`,
  );
  return result.rows;
}

export async function reviewProfile(
  profileId: string,
  reviewerId: string,
  data: ProfileReviewInput,
) {
  return transaction(async (client) => {
    const result = await client.query<ProfileRow>(
      `SELECT * FROM specialized_profiles
        WHERE id = $1 AND verification_status IN ('submitted', 'pending_review')
        FOR UPDATE`,
      [profileId],
    );
    const profile = result.rows[0];
    if (!profile) return null;
    const status = data.decision === 'approved'
      ? 'approved'
      : data.decision === 'suspended'
        ? 'suspended'
        : 'rejected';
    const updated = await client.query(
      `UPDATE specialized_profiles
          SET verification_status = $1, reviewed_at = NOW(), reviewed_by = $2,
              rejection_reason = $3, updated_at = NOW()
        WHERE id = $4 RETURNING *`,
      [status, reviewerId, data.rejectionReason ?? null, profileId],
    );
    const reviewedDocuments = await markProfileVerificationDocumentsReviewed(
      client, profileId, reviewerId,
    );
    await client.query(
      `INSERT INTO profile_verification_records
        (specialized_profile_id, previous_status, new_status, reviewed_by, reviewer_role,
         decision, review_notes, rejection_reason, requested_changes, reviewed_at, documents_reviewed)
       VALUES ($1,$2,$3,$4,'system_admin',$5,$6,$7,$8,NOW(),$9)`,
      [
        profileId, profile.verification_status, status, reviewerId, data.decision,
        data.reviewNotes ?? null, data.rejectionReason ?? null, data.requestedChanges ?? null,
        JSON.stringify(reviewedDocuments),
      ],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','profile.verification.review','specialized_profile',$2,$3,$4)`,
      [
        reviewerId, profileId, profile.organisation_id,
        JSON.stringify({ decision: data.decision, status }),
      ],
    );
    await calculateCompletion(client, updated.rows[0]);
    return updated.rows[0];
  });
}

export async function getOrganizationProfile(organizationId: string, userId: string) {
  const result = await pool.query(
    `SELECT o.id, o.name, o.type AS category, o.description, o.contact_email AS "contactEmail",
            o.contact_phone AS "contactPhone", o.address, o.city, o.county, o.country,
            CASE WHEN om.role IN ('owner', 'admin') THEN o.registration_number END AS "registrationNumber",
            CASE WHEN om.role IN ('owner', 'admin') THEN o.tax_id END AS "taxId",
            o.logo_url AS "logoUrl", o.website_url AS "websiteUrl",
            o.latitude, o.longitude, o.place_id AS "placeId",
            o.neighbourhood AS neighborhood, o.location_source AS "locationSource",
            o.location_confirmed_at AS "locationConfirmedAt",
            o.verification_status AS "verificationStatus", o.is_verified AS "isVerified",
            o.created_at AS "createdAt", o.updated_at AS "updatedAt",
            om.role AS "membershipRole",
            (om.role IN ('owner', 'admin')) AS "canEdit"
       FROM organisations o
       JOIN organisation_members om ON om.organisation_id = o.id
      WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'`,
    [organizationId, userId],
  );
  const profile = result.rows[0];
  if (!profile) return null;
  const requirements = ['name', 'description', 'contact', 'officeAddress', 'officeCoordinates'];
  const missingFields = requirements.filter((field) => {
    if (field === 'contact') {
      return !profile.contactEmail?.trim() && !profile.contactPhone?.trim();
    }
    if (field === 'officeAddress') return !profile.address?.trim();
    if (field === 'officeCoordinates') {
      return profile.latitude === null || profile.latitude === undefined ||
        profile.longitude === null || profile.longitude === undefined;
    }
    return !profile[field]?.trim();
  });
  const completionPercentage = Math.round(
    ((requirements.length - missingFields.length) / requirements.length) * 100,
  );
  return {
    ...profile,
    completion: {
      completionPercentage,
      missingFields,
      canSubmit: missingFields.length === 0,
    },
  };
}

export async function updateOrganizationProfile(
  organizationId: string,
  userId: string,
  data: OrganizationProfileInput,
) {
  return transaction(async (client) => {
    const member = await client.query<{ role: string }>(
      `SELECT role FROM organisation_members
        WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'
        FOR UPDATE`,
      [organizationId, userId],
    );
    if (!['owner', 'admin'].includes(member.rows[0]?.role ?? '')) return null;
    const organizationState = await client.query<{ verification_status: string }>(
      'SELECT verification_status FROM organisations WHERE id = $1 FOR UPDATE',
      [organizationId],
    );
    if (!organizationState.rows[0]) return null;
    const columns = {
      name: 'name',
      description: 'description',
      contactEmail: 'contact_email',
      contactPhone: 'contact_phone',
      address: 'address',
      city: 'city',
      county: 'county',
      country: 'country',
      registrationNumber: 'registration_number',
      taxId: 'tax_id',
      logoUrl: 'logo_url',
      websiteUrl: 'website_url',
      latitude: 'latitude',
      longitude: 'longitude',
      placeId: 'place_id',
      neighborhood: 'neighbourhood',
      locationSource: 'location_source',
    } as const;
    const entries = Object.entries(data).filter(([key]) => key in columns);
    if (!entries.length) return getOrganizationProfile(organizationId, userId);
    const values: unknown[] = [];
    const setters = entries.map(([key, value], index) => {
      values.push(value);
      return `${columns[key as keyof typeof columns]} = $${index + 1}`;
    });
    const previousStatus = organizationState.rows[0].verification_status;
    if (['verified', 'in_review', 'rejected'].includes(previousStatus)) {
      setters.push(
        `verification_status = 'pending'`,
        'is_verified = FALSE',
        'verified_at = NULL',
        'verified_by = NULL',
        'verification_notes = NULL',
      );
    }
    if (data.latitude !== undefined) {
      setters.push(data.latitude === null
        ? 'location_confirmed_at = NULL'
        : 'location_confirmed_at = NOW()');
    }
    values.push(organizationId);
    await client.query(
      `UPDATE organisations SET ${setters.join(', ')}, updated_at = NOW()
        WHERE id = $${values.length}`,
      values,
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','organization.profile.update','organization',$2,$2,$3)`,
      [userId, organizationId, JSON.stringify({ updatedFields: entries.map(([key]) => key) })],
    );
    if (['verified', 'in_review', 'rejected'].includes(previousStatus)) {
      await client.query(
        `INSERT INTO organization_verification_records
          (organization_id, previous_status, new_status, decision)
         VALUES ($1,$2,'pending','profile_updated')`,
        [organizationId, previousStatus],
      );
    }
    const updated = await client.query(
      `SELECT o.id, o.name, o.type AS category, o.description, o.contact_email AS "contactEmail",
              o.contact_phone AS "contactPhone", o.address, o.city, o.county, o.country,
              o.registration_number AS "registrationNumber", o.tax_id AS "taxId",
              o.logo_url AS "logoUrl", o.website_url AS "websiteUrl",
              o.latitude, o.longitude, o.place_id AS "placeId",
              o.neighbourhood AS neighborhood, o.location_source AS "locationSource",
              o.location_confirmed_at AS "locationConfirmedAt",
              o.verification_status AS "verificationStatus", o.is_verified AS "isVerified",
              o.created_at AS "createdAt", o.updated_at AS "updatedAt",
              om.role AS "membershipRole",
              (om.role IN ('owner', 'admin')) AS "canEdit"
         FROM organisations o
         JOIN organisation_members om ON om.organisation_id = o.id
        WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'`,
      [organizationId, userId],
    );
    const updatedProfile = updated.rows[0];
    if (!updatedProfile) return null;
    const requirements = ['name', 'description', 'contact', 'officeAddress', 'officeCoordinates'];
    const missingFields = requirements.filter((field) => {
      if (field === 'contact') {
        return !updatedProfile.contactEmail?.trim() && !updatedProfile.contactPhone?.trim();
      }
      if (field === 'officeAddress') return !updatedProfile.address?.trim();
      if (field === 'officeCoordinates') {
        return updatedProfile.latitude === null || updatedProfile.latitude === undefined ||
          updatedProfile.longitude === null || updatedProfile.longitude === undefined;
      }
      return !updatedProfile[field]?.trim();
    });
    return {
      ...updatedProfile,
      completion: {
        completionPercentage: Math.round(
          ((requirements.length - missingFields.length) / requirements.length) * 100,
        ),
        missingFields,
        canSubmit: missingFields.length === 0,
      },
    };
  });
}

export async function submitOrganizationForReview(organizationId: string, userId: string) {
  return transaction(async (client) => {
    const result = await client.query(
      `SELECT o.* FROM organisations o
        JOIN organisation_members om ON om.organisation_id = o.id
       WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'
         AND om.role IN ('owner', 'admin')
       FOR UPDATE OF o`,
      [organizationId, userId],
    );
    const organization = result.rows[0];
    if (!organization) return null;
    if (organization.verification_status === 'verified') {
      throw new ValidationError('A verified organization cannot be resubmitted without profile changes');
    }
    const requirements = ['name', 'description', 'contact', 'officeAddress', 'officeCoordinates'];
    const missingFields = requirements.filter((field) => {
      if (field === 'contact') {
        return !organization.contact_email?.trim() && !organization.contact_phone?.trim();
      }
      if (field === 'officeAddress') return !organization.address?.trim();
      if (field === 'officeCoordinates') {
        return organization.latitude === null || organization.latitude === undefined ||
          organization.longitude === null || organization.longitude === undefined;
      }
      return !organization[field]?.trim();
    });
    if (missingFields.length) {
      throw new ValidationError(`Complete required organization fields before submitting: ${missingFields.join(', ')}`);
    }
    const updated = await client.query(
      `UPDATE organisations SET verification_status = 'in_review', updated_at = NOW()
        WHERE id = $1 RETURNING *`,
      [organizationId],
    );
    const documents = await client.query(
      `SELECT id, document_type AS "documentType", created_at AS "uploadedAt"
         FROM profile_verification_documents
        WHERE organization_id = $1 AND status = 'submitted' ORDER BY created_at`,
      [organizationId],
    );
    await client.query(
      `INSERT INTO organization_verification_records
        (organization_id, previous_status, new_status, decision, documents_submitted)
       VALUES ($1,$2,'in_review','submitted',$3)`,
      [organizationId, organization.verification_status, JSON.stringify(documents.rows)],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','organization.profile.submit','organization',$2,$2,$3)`,
      [userId, organizationId, JSON.stringify({ previousStatus: organization.verification_status })],
    );
    return updated.rows[0];
  });
}

export async function listOrganizationVerificationRecords(
  organizationId: string,
  userId: string,
) {
  const access = await pool.query(
    `SELECT 1 FROM organisation_members
      WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'`,
    [organizationId, userId],
  );
  if (!access.rowCount) return null;
  const result = await pool.query(
    `SELECT id, organization_id AS "organizationId",
            previous_status AS "previousStatus", new_status AS "newStatus",
            decision, rejection_reason AS "rejectionReason",
            requested_changes AS "requestedChanges", submitted_at AS "submittedAt",
            reviewed_at AS "reviewedAt", created_at AS "createdAt"
       FROM organization_verification_records
      WHERE organization_id = $1 ORDER BY created_at DESC`,
    [organizationId],
  );
  return result.rows;
}

export async function listOrganizationsForReview() {
  const result = await pool.query(
    `SELECT id, name, type AS category, description,
            contact_email AS "contactEmail", contact_phone AS "contactPhone",
            address, city, county, country, verification_status AS "verificationStatus",
            created_at AS "createdAt"
       FROM organisations WHERE verification_status = 'in_review'
      ORDER BY updated_at ASC`,
  );
  return result.rows;
}

export async function reviewOrganization(
  organizationId: string,
  reviewerId: string,
  data: OrganizationReviewInput,
) {
  return transaction(async (client) => {
    const result = await client.query(
      `SELECT id, verification_status FROM organisations
        WHERE id = $1 AND verification_status = 'in_review'
        FOR UPDATE`,
      [organizationId],
    );
    const organization = result.rows[0];
    if (!organization) return null;
    const status = data.decision === 'approved' ? 'verified' : 'rejected';
    const updated = await client.query(
      `UPDATE organisations
          SET verification_status = $1, is_verified = $2,
              verified_at = CASE WHEN $2 THEN NOW() ELSE NULL END,
              verified_by = CASE WHEN $2 THEN $3 ELSE NULL END,
              verification_notes = $4, updated_at = NOW()
        WHERE id = $5 RETURNING id, name, verification_status AS "verificationStatus",
              is_verified AS "isVerified", verified_at AS "verifiedAt",
              verified_by AS "verifiedBy"`,
      [
        status, data.decision === 'approved', reviewerId,
        data.reviewNotes ?? data.rejectionReason ?? null, organizationId,
      ],
    );
    const reviewedDocuments = await client.query(
      `UPDATE profile_verification_documents SET status = 'reviewed', reviewed_by = $2,
         reviewed_at = NOW(), updated_at = NOW()
        WHERE organization_id = $1 AND status = 'submitted'
        RETURNING id, document_type AS "documentType"`,
      [organizationId, reviewerId],
    );
    await client.query(
      `INSERT INTO organization_verification_records
        (organization_id, previous_status, new_status, reviewed_by, decision,
         review_notes, rejection_reason, requested_changes, reviewed_at, documents_reviewed)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW(),$9)`,
      [
        organizationId, organization.verification_status, status, reviewerId, data.decision,
        data.reviewNotes ?? null, data.rejectionReason ?? null, data.requestedChanges ?? null,
        JSON.stringify(reviewedDocuments.rows),
      ],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','organization.verification.review','organization',$2,$2,$3)`,
      [reviewerId, organizationId, JSON.stringify({ decision: data.decision, status })],
    );
    return updated.rows[0] ?? null;
  });
}

export type VerificationDocumentInput = {
  storageKey: string;
  fileName: string;
  mimeType: string;
  byteSize: number;
  sha256: string;
  documentType: string;
};

export async function canUploadVerificationDocument(userId: string, scope: { profileId: string } | { organizationId: string }) {
  const result = 'profileId' in scope
    ? await pool.query(
      `SELECT 1 FROM specialized_profiles sp WHERE sp.id = $1 AND sp.verification_status <> 'suspended'
        AND (sp.user_id = $2 OR EXISTS (
          SELECT 1 FROM organisation_members om WHERE om.organisation_id = sp.organisation_id
            AND om.user_id = $2 AND om.status = 'active' AND om.role IN ('owner','admin')
        ))`, [scope.profileId, userId],
    )
    : await pool.query(
      `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2
        AND status = 'active' AND role IN ('owner','admin')`, [scope.organizationId, userId],
    );
  return result.rowCount !== 0;
}

export async function createProfileVerificationDocument(
  profileId: string,
  userId: string,
  data: VerificationDocumentInput,
) {
  return transaction(async (client) => {
    const profile = await manageableProfile(client, profileId, userId);
    if (!profile) return null;
    if (profile.verification_status === 'suspended') {
      throw new ValidationError('Documents cannot be added to a suspended profile');
    }
    const result = await client.query(
      `INSERT INTO profile_verification_documents
        (specialized_profile_id, uploaded_by, storage_key, original_file_name,
         mime_type, byte_size, sha256, document_type)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING id, specialized_profile_id AS "specializedProfileId",
         original_file_name AS "fileName", mime_type AS "mimeType",
         byte_size AS "byteSize", sha256, document_type AS "documentType",
         status, created_at AS "createdAt"`,
      [profileId, userId, data.storageKey, data.fileName, data.mimeType,
        data.byteSize, data.sha256, data.documentType],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','profile.verification_document.upload','profile_verification_document',$2,$3,$4)`,
      [userId, result.rows[0].id, profile.organisation_id,
        JSON.stringify({ profileId, fileName: data.fileName, documentType: data.documentType })],
    );
    return result.rows[0];
  });
}

export async function createOrganizationVerificationDocument(
  organizationId: string,
  userId: string,
  data: VerificationDocumentInput,
) {
  return transaction(async (client) => {
    const organization = await client.query<{ id: string; verification_status: string }>(
      `SELECT o.id, o.verification_status FROM organisations o
         JOIN organisation_members om ON om.organisation_id = o.id
        WHERE o.id = $1 AND om.user_id = $2 AND om.status = 'active'
          AND om.role IN ('owner', 'admin') FOR UPDATE OF o`,
      [organizationId, userId],
    );
    if (!organization.rows[0]) return null;
    const result = await client.query(
      `INSERT INTO profile_verification_documents
        (organization_id, uploaded_by, storage_key, original_file_name,
         mime_type, byte_size, sha256, document_type)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING id, organization_id AS "organizationId",
         original_file_name AS "fileName", mime_type AS "mimeType",
         byte_size AS "byteSize", sha256, document_type AS "documentType",
         status, created_at AS "createdAt"`,
      [organizationId, userId, data.storageKey, data.fileName, data.mimeType,
        data.byteSize, data.sha256, data.documentType],
    );
    await client.query(
      `INSERT INTO authorization_audit
        (user_id, decision, permission_id, resource_type, resource_id, organization_id, metadata)
       VALUES ($1,'allow','organization.verification_document.upload','profile_verification_document',$2,$2,$3)`,
      [userId, result.rows[0].id, JSON.stringify({ organizationId, fileName: data.fileName })],
    );
    return result.rows[0];
  });
}

export async function listProfileVerificationDocuments(profileId: string, userId: string, isAdmin = false) {
  const access = isAdmin ? { rowCount: 1 } : await pool.query(
    `SELECT 1 FROM specialized_profiles sp WHERE sp.id = $1 AND (
       sp.user_id = $2 OR EXISTS (
         SELECT 1 FROM organisation_members om WHERE om.organisation_id = sp.organisation_id
           AND om.user_id = $2 AND om.status = 'active' AND om.role IN ('owner','admin')
       ))`,
    [profileId, userId],
  );
  if (!access.rowCount) return null;
  const result = await pool.query(
    `SELECT id, specialized_profile_id AS "specializedProfileId",
       original_file_name AS "fileName", mime_type AS "mimeType", byte_size AS "byteSize",
       sha256, document_type AS "documentType", status, created_at AS "createdAt"
       FROM profile_verification_documents
      WHERE specialized_profile_id = $1 AND status <> 'deleted' ORDER BY created_at DESC`,
    [profileId],
  );
  return result.rows;
}

export async function listOrganizationVerificationDocuments(organizationId: string, userId: string, isAdmin = false) {
  const access = isAdmin ? { rowCount: 1 } : await pool.query(
    `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2
       AND status = 'active' AND role IN ('owner','admin')`,
    [organizationId, userId],
  );
  if (!access.rowCount) return null;
  const result = await pool.query(
    `SELECT id, organization_id AS "organizationId", original_file_name AS "fileName",
       mime_type AS "mimeType", byte_size AS "byteSize", sha256,
       document_type AS "documentType", status, created_at AS "createdAt"
       FROM profile_verification_documents
      WHERE organization_id = $1 AND status <> 'deleted' ORDER BY created_at DESC`,
    [organizationId],
  );
  return result.rows;
}

export async function getVerificationDocumentForAccess(documentId: string, userId: string, isAdmin: boolean) {
  return transaction(async (client) => {
    const result = await client.query(
      `SELECT d.id, d.specialized_profile_id AS "specializedProfileId",
          d.organization_id AS "organizationId", d.storage_key AS "storageKey",
          d.original_file_name AS "fileName", d.mime_type AS "mimeType", d.status,
          sp.user_id AS "profileOwnerId", sp.organisation_id AS "profileOrganizationId",
          o.id AS "existingOrganizationId"
         FROM profile_verification_documents d
         LEFT JOIN specialized_profiles sp ON sp.id = d.specialized_profile_id
         LEFT JOIN organisations o ON o.id = d.organization_id
        WHERE d.id = $1`, [documentId],
    );
    const doc = result.rows[0];
    if (!doc) return null;
    const membershipOrgId = doc.organizationId ?? doc.profileOrganizationId;
    let member = false;
    if (membershipOrgId) {
      const membership = await client.query(
        `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2
           AND status = 'active' AND role IN ('owner','admin')`,
        [membershipOrgId, userId],
      );
      member = membership.rowCount !== 0;
    }
    const allowed = doc.status !== 'deleted' && (isAdmin || doc.profileOwnerId === userId || member);
    await client.query(
      `INSERT INTO profile_verification_document_access_log
        (document_id, user_id, action, access_granted) VALUES ($1,$2,'signed_url', $3)`,
      [doc.id, userId, allowed],
    );
    if (!allowed) return false;
    return doc as { storageKey: string; fileName: string; mimeType: string };
  });
}

export async function markProfileVerificationDocumentsReviewed(
  client: PoolClient,
  profileId: string,
  reviewerId: string,
): Promise<unknown[]> {
  const result = await client.query(
    `UPDATE profile_verification_documents SET status = 'reviewed', reviewed_by = $2,
       reviewed_at = NOW(), updated_at = NOW()
      WHERE specialized_profile_id = $1 AND status = 'submitted'
      RETURNING id, document_type AS "documentType"`,
    [profileId, reviewerId],
  );
  return result.rows;
}
