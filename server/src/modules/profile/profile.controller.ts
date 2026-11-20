import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError, ValidationError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import * as svc from './profile.service.js';
import * as places from './google-places.service.js';
import * as verificationDocuments from './verification-document.service.js';

function currentUser(req: Request): AuthUser {
  const user = req.user as AuthUser | undefined;
  if (!user) throw new UnauthorizedError();
  return user;
}

function param(req: Request, key: string): string {
  const value = req.params[key];
  return (Array.isArray(value) ? value[0] : value) ?? '';
}

function sendResult(res: Response, data: unknown) {
  if (data === null || data === undefined || data === false) {
    return res.status(404).json({ success: false, message: 'Not found' });
  }
  return res.json({ success: true, data });
}

export async function getPersonal(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await svc.personal.get(currentUser(req).id) });
  } catch (error) {
    next(error);
  }
}

export async function updatePersonal(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await svc.personal.update(currentUser(req).id, req.body) });
  } catch (error) {
    next(error);
  }
}

export async function uploadImage(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.file) throw new ValidationError('An image file is required');
    const data = await svc.uploads.image(currentUser(req).id, req.body, req.file);
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function listSpecialized(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await svc.specialized.list(currentUser(req).id) });
  } catch (error) {
    next(error);
  }
}

export async function createSpecialized(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await svc.specialized.create(currentUser(req).id, req.body);
    if (!data) return res.status(404).json({ success: false, message: 'Organization membership required' });
    return res.status(201).json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function getSpecialized(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.specialized.get(param(req, 'id'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function updateSpecialized(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.specialized.update(param(req, 'id'), currentUser(req).id, req.body));
  } catch (error) {
    next(error);
  }
}

export async function submitSpecialized(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.specialized.submit(param(req, 'id'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function getProviderExtension(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.specialized.providerExtension.get(param(req, 'id'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function upsertProviderExtension(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.specialized.providerExtension.upsert(param(req, 'id'), currentUser(req).id, req.body),
    );
  } catch (error) {
    next(error);
  }
}

export async function getLaundryServices(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.specialized.laundryServices.get(param(req, 'providerProfileId'), currentUser(req).id),
    );
  } catch (error) {
    next(error);
  }
}

export async function upsertLaundryServices(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.specialized.laundryServices.upsert(
        param(req, 'providerProfileId'),
        currentUser(req).id,
        req.body,
      ),
    );
  } catch (error) {
    next(error);
  }
}

export async function getCompletion(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.specialized.completion.get(param(req, 'id'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function listVerification(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.verification.list(param(req, 'id'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function saveLocation(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.locations.save(currentUser(req).id, req.body));
  } catch (error) {
    next(error);
  }
}

export async function listLocations(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.locations.list(
        currentUser(req).id,
        typeof req.query.profileId === 'string' ? req.query.profileId : undefined,
      ),
    );
  } catch (error) {
    next(error);
  }
}

export async function searchPlaces(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await places.autocomplete(String(req.query.input)) });
  } catch (error) {
    next(error);
  }
}

export async function getPlace(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await places.details(param(req, 'placeId')) });
  } catch (error) {
    next(error);
  }
}

export async function uploadProfileVerificationDocument(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.file) throw new ValidationError('A verification document file is required');
    const data = await verificationDocuments.upload(
      currentUser(req).id, { profileId: param(req, 'id') }, req.body, req.file,
    );
    res.status(201).json({ success: true, data });
  } catch (error) { next(error); }
}

export async function uploadOrganizationVerificationDocument(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.file) throw new ValidationError('A verification document file is required');
    const data = await verificationDocuments.upload(
      currentUser(req).id, { organizationId: param(req, 'organizationId') }, req.body, req.file,
    );
    res.status(201).json({ success: true, data });
  } catch (error) { next(error); }
}

export async function listProfileVerificationDocuments(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.list(
      currentUser(req).id, { profileId: param(req, 'id') },
    ));
  } catch (error) { next(error); }
}

export async function adminListProfileVerificationDocuments(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.list(
      currentUser(req).id, { profileId: param(req, 'id') }, true,
    ));
  } catch (error) { next(error); }
}

export async function listOrganizationVerificationDocuments(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.list(
      currentUser(req).id, { organizationId: param(req, 'organizationId') },
    ));
  } catch (error) { next(error); }
}

export async function adminListOrganizationVerificationDocuments(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.list(
      currentUser(req).id, { organizationId: param(req, 'organizationId') }, true,
    ));
  } catch (error) { next(error); }
}

export async function verificationDocumentDownloadUrl(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.downloadUrl(
      currentUser(req).id, param(req, 'documentId'),
    ));
  } catch (error) { next(error); }
}

export async function adminVerificationDocumentDownloadUrl(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await verificationDocuments.downloadUrl(
      currentUser(req).id, param(req, 'documentId'), true,
    ));
  } catch (error) { next(error); }
}

export async function addServiceArea(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await svc.serviceAreas.add(currentUser(req).id, req.body);
    if (!data) return res.status(404).json({ success: false, message: 'Provider profile not found' });
    return res.status(201).json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function listServiceAreas(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.serviceAreas.list(param(req, 'profileId'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function updateServiceArea(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.serviceAreas.update(param(req, 'areaId'), currentUser(req).id, req.body),
    );
  } catch (error) {
    next(error);
  }
}

export async function deleteServiceArea(req: Request, res: Response, next: NextFunction) {
  try {
    const deleted = await svc.serviceAreas.delete(param(req, 'areaId'), currentUser(req).id);
    return sendResult(res, deleted ? { deleted: true } : null);
  } catch (error) {
    next(error);
  }
}

export async function getOrganizationProfile(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(res, await svc.organizations.get(param(req, 'organizationId'), currentUser(req).id));
  } catch (error) {
    next(error);
  }
}

export async function updateOrganizationProfile(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.organizations.update(param(req, 'organizationId'), currentUser(req).id, req.body),
    );
  } catch (error) {
    next(error);
  }
}

export async function submitOrganizationProfile(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.organizations.submit(param(req, 'organizationId'), currentUser(req).id),
    );
  } catch (error) {
    next(error);
  }
}

export async function organizationVerificationRecords(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    return sendResult(
      res,
      await svc.organizations.verificationRecords(
        param(req, 'organizationId'),
        currentUser(req).id,
      ),
    );
  } catch (error) {
    next(error);
  }
}

export async function profileReviewQueue(_req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await svc.verification.queue() });
  } catch (error) {
    next(error);
  }
}

export async function organizationReviewQueue(
  _req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    res.json({ success: true, data: await svc.organizations.verificationQueue() });
  } catch (error) {
    next(error);
  }
}

export async function reviewProfile(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.verification.review(param(req, 'id'), currentUser(req).id, req.body),
    );
  } catch (error) {
    next(error);
  }
}

export async function reviewOrganization(req: Request, res: Response, next: NextFunction) {
  try {
    return sendResult(
      res,
      await svc.organizations.review(
        param(req, 'organizationId'),
        currentUser(req).id,
        req.body,
      ),
    );
  } catch (error) {
    next(error);
  }
}
