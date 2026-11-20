import { SignJWT, jwtVerify } from 'jose';
import type { PropertyDocument, DocumentVisibility } from './auth.types.js';
import { loadEnv } from '../../config/env.js';

const env = loadEnv();
const SIGNED_URL_SECRET = env.JWT_PRIVATE_KEY;
const SIGNED_URL_TTL = 3600; // 1 hour default

function getSecretKey(): Uint8Array {
  return new TextEncoder().encode(SIGNED_URL_SECRET);
}

export interface SignedUrlPayload {
  documentId: string;
  userId: string;
  purpose: 'download' | 'view';
  iat: number;
  exp: number;
}

export async function createSignedDocumentUrl(
  document: PropertyDocument,
  userId: string,
  purpose: 'download' | 'view' = 'view',
  ttlSeconds: number = SIGNED_URL_TTL
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload: SignedUrlPayload = {
    documentId: document.id,
    userId,
    purpose,
    iat: now,
    exp: now + ttlSeconds,
  };

  const token = await new SignJWT(payload as any)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt(now)
    .setExpirationTime(now + ttlSeconds)
    .sign(getSecretKey());

  const baseUrl = env.EMAIL_BASE_URL || 'http://localhost:3000';
  return `${baseUrl}/api/v1/auth/documents/${document.id}/signed?token=${token}`;
}

export async function verifySignedDocumentUrl(token: string): Promise<SignedUrlPayload | null> {
  try {
    const { payload } = await jwtVerify(token, getSecretKey());
    return payload as unknown as SignedUrlPayload;
  } catch {
    return null;
  }
}

export async function canAccessDocumentViaSignedUrl(
  document: PropertyDocument,
  payload: SignedUrlPayload
): Promise<boolean> {
  if (payload.documentId !== document.id) return false;
  if (payload.exp < Math.floor(Date.now() / 1000)) return false;

  // Check if document is still active and not expired
  if (document.status !== 'active') return false;
  if (document.expiresAt && new Date(document.expiresAt) < new Date()) return false;

  // Check visibility and permissions
  switch (document.visibility as DocumentVisibility) {
    case 'public':
      return true;
    case 'participant':
      // In a real implementation, you'd check if the user is a participant
      // For now, we trust the signed URL was issued to an authorized user
      return true;
    case 'owner':
    case 'manager':
      // The signed URL issuance already verified access
      return true;
    default:
      return false;
  }
}

export async function generateDocumentSignedUrl(
  documentId: string,
  userId: string,
  purpose: 'download' | 'view' = 'view',
  ttlSeconds?: number
): Promise<{ signedUrl: string; expiresAt: Date } | null> {
  const document = await import('./auth.repository.js').then(m => m.findPropertyDocumentById(documentId));
  if (!document) return null;

  // Verify user has access to this document
  const authz = await import('./authorization.service.js');
  const decision = await authz.canAccessPropertyDocument(userId, documentId);
  if (!decision.allowed) return null;

  const signedUrl = await createSignedDocumentUrl(document, userId, purpose, ttlSeconds);
  const expiresAt = new Date(Date.now() + (ttlSeconds || SIGNED_URL_TTL) * 1000);

  return { signedUrl, expiresAt };
}