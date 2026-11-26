import type { NextFunction, Request, Response } from "express";
import * as repository from "./listings.repository.js";

export async function directions(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await repository.calculateRoute(req.body);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function nearby(req: Request, res: Response, next: NextFunction) {
  try {
    const data = await repository.findNearbyListings(req.query as never);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}
