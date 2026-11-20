import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { loadEnv } from '../../config/env.js';
import { HttpError } from '../../shared/errors.js';

function configuredStorage() {
  const env = loadEnv();
  if (!env.AWS_S3_PRIVATE_BUCKET || !env.AWS_REGION) {
    throw new HttpError('Private document storage is not configured on this server', 503);
  }
  return { bucket: env.AWS_S3_PRIVATE_BUCKET, client: new S3Client({ region: env.AWS_REGION }) };
}

export async function putPrivateDocument(key: string, buffer: Buffer, contentType: string) {
  const { bucket, client } = configuredStorage();
  await client.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: buffer,
    ContentType: contentType,
    ServerSideEncryption: 'AES256',
  }));
}

export async function deletePrivateDocument(key: string): Promise<void> {
  const { bucket, client } = configuredStorage();
  await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
}

export async function signedPrivateDocumentUrl(
  key: string,
  fileName: string,
  contentType: string,
): Promise<string> {
  const { bucket, client } = configuredStorage();
  const command = new GetObjectCommand({
    Bucket: bucket,
    Key: key,
    ResponseContentType: contentType,
    ResponseContentDisposition: `attachment; filename="${fileName.replace(/["\\\r\n]/g, '_')}"`,
  });
  return getSignedUrl(client, command, { expiresIn: 300 });
}
