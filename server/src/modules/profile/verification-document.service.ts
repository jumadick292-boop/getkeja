import { randomUUID } from 'node:crypto';
import * as repo from './profile.repository.js';
import {
  deletePrivateDocument,
  putPrivateDocument,
  signedPrivateDocumentUrl,
} from './private-document-storage.service.js';
import { validateVerificationDocument } from './verification-document-upload.validation.js';
import { ForbiddenError, HttpError, ValidationError } from '../../shared/errors.js';

type Scope = { profileId: string } | { organizationId: string };

function cleanFileName(value: string): string {
  const name = value.split(/[\\/]/).pop()?.replace(/[\r\n\0]/g, '_').trim() ?? '';
  if (!name || name.length > 255) throw new ValidationError('Invalid document file name');
  return name;
}

export async function upload(
  userId: string,
  scope: Scope,
  input: { documentType: string },
  file: { buffer: Buffer; mimetype: string; size: number; originalname: string },
) {
  if (!await repo.canUploadVerificationDocument(userId, scope)) {
    throw new ForbiddenError('You cannot upload a verification document for this profile');
  }
  const { sha256 } = await validateVerificationDocument(file);
  const fileName = cleanFileName(file.originalname);
  const scopePath = 'profileId' in scope ? `profiles/${scope.profileId}` : `organizations/${scope.organizationId}`;
  const storageKey = `verification/${scopePath}/${randomUUID()}`;
  await putPrivateDocument(storageKey, file.buffer, file.mimetype);
  try {
    const metadata = {
      storageKey, fileName, mimeType: file.mimetype, byteSize: file.size,
      sha256, documentType: input.documentType,
    };
    const saved = 'profileId' in scope
      ? await repo.createProfileVerificationDocument(scope.profileId, userId, metadata)
      : await repo.createOrganizationVerificationDocument(scope.organizationId, userId, metadata);
    if (!saved) throw new ForbiddenError('You cannot upload a verification document for this profile');
    return saved;
  } catch (error) {
    await deletePrivateDocument(storageKey).catch(() => undefined);
    throw error;
  }
}

export async function list(userId: string, scope: Scope, isAdmin = false) {
  return 'profileId' in scope
    ? repo.listProfileVerificationDocuments(scope.profileId, userId, isAdmin)
    : repo.listOrganizationVerificationDocuments(scope.organizationId, userId, isAdmin);
}

export async function downloadUrl(userId: string, documentId: string, isAdmin = false) {
  const doc = await repo.getVerificationDocumentForAccess(documentId, userId, isAdmin);
  if (doc === false) throw new ForbiddenError('You cannot access this verification document');
  if (!doc) throw new HttpError('Verification document not found', 404);
  return {
    url: await signedPrivateDocumentUrl(doc.storageKey, cleanFileName(doc.fileName), doc.mimeType),
    expiresInSeconds: 300,
  };
}
