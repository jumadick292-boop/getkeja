import type { ErrorRequestHandler, Request, RequestHandler } from 'express';
import type { Logger } from 'pino';

interface HttpError extends Error {
  status?: number;
  statusCode?: number;
  type?: string;
}

type RequestWithLogger = Request & { log?: Logger };

export const notFoundHandler: RequestHandler = (req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`,
    code: 'NOT_FOUND',
  });
};

export const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) {
    next(err);
    return;
  }

  const error = err instanceof Error ? (err as HttpError) : undefined;
  const status = resolveStatus(error);
  const log = (req as RequestWithLogger).log;

  if (status >= 500) {
    log?.error({ err, statusCode: status }, 'request failed');
  } else {
    log?.warn({ err, statusCode: status }, 'request rejected');
  }

  res.status(status).json({
    success: false,
    message: resolveMessage(status, error),
    code: resolveCode(status, error),
  });
};

function resolveStatus(error: HttpError | undefined): number {
  if (!error) return 500;
  if (error.type === 'entity.too.large') return 413;
  if (error.type === 'entity.parse.failed') return 400;
  const status = error.status ?? error.statusCode;
  return status && status >= 400 && status <= 599 ? status : 500;
}

function resolveCode(status: number, error: HttpError | undefined): string {
  if (error?.type === 'entity.too.large') return 'PAYLOAD_TOO_LARGE';
  if (error?.type === 'entity.parse.failed') return 'INVALID_JSON';
  if (status >= 500) return 'INTERNAL_ERROR';
  if (status === 429) return 'RATE_LIMITED';
  if (status === 401) return 'UNAUTHORIZED';
  if (status === 403) return 'FORBIDDEN';
  if (status === 404) return 'NOT_FOUND';
  if (status === 409) return 'CONFLICT';
  return 'VALIDATION_ERROR';
}

function resolveMessage(status: number, error: HttpError | undefined): string {
  if (error?.type === 'entity.too.large') return 'Request body is too large';
  if (error?.type === 'entity.parse.failed') return 'Malformed JSON in request body';
  if (status >= 500 || !error?.message) return 'Internal server error';
  return error.message;
}