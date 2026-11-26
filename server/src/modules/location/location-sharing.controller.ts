import type { NextFunction, Request, Response } from 'express';
import type { AuthUser } from '../auth/auth.types.js';
import * as repository from './location-sharing.repository.js';
import * as providerDiscovery from './provider-discovery.repository.js';

function userId(req: Request) {
  return (req.user as AuthUser).id;
}

export async function start(req: Request, res: Response, next: NextFunction) {
  try {
    res
      .status(201)
      .json({
        success: true,
        data: await repository.start(userId(req), req.body),
      });
  } catch (error) {
    next(error);
  }
}

export async function update(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      success: true,
      data: await repository.update(
        userId(req),
        String(req.params.sessionId),
        req.body,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function list(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({ success: true, data: await repository.listOwned(userId(req)) });
  } catch (error) {
    next(error);
  }
}

export async function listSharedWithMe(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    res.json({
      success: true,
      data: await repository.listSharedWithMe(userId(req)),
    });
  } catch (error) {
    next(error);
  }
}

export async function listEligibleVisits(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    res.json({
      success: true,
      data: await repository.listEligibleVisits(userId(req)),
    });
  } catch (error) {
    next(error);
  }
}

export async function sharedLocation(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    res.json({
      success: true,
      data: await repository.retrieveSharedLocation(
        userId(req),
        String(req.params.sessionId),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function stop(req: Request, res: Response, next: NextFunction) {
  try {
    res.json({
      success: true,
      data: await repository.stop(userId(req), String(req.params.sessionId)),
    });
  } catch (error) {
    next(error);
  }
}

export async function discoverProviders(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    res.json({
      success: true,
      data: await providerDiscovery.findProviders(req.query as never),
    });
  } catch (error) {
    next(error);
  }
}
