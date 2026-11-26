import { Router } from "express";
import { validate } from "../../middleware/validate.js";
import { createRateLimiter } from "../../middleware/rate-limit.js";
import { requireAuth } from "../auth/auth.middleware.js";
import * as controller from "./listings.controller.js";
import { directionsRequestSchema, nearbyListingsQuerySchema } from "./listings.schema.js";

const router = Router();
router.use(requireAuth);
router.get(
  "/nearby",
  createRateLimiter({
    windowMs: 60_000,
    max: 60,
    keyPrefix: "listings:nearby",
    identifierField: "userId",
  }),
  validate(nearbyListingsQuerySchema, "query"),
  controller.nearby,
);
router.post(
  "/directions",
  createRateLimiter({
    windowMs: 60_000,
    max: 20,
    keyPrefix: "listings:directions",
    identifierField: "userId",
  }),
  validate(directionsRequestSchema),
  controller.directions,
);

export function createListingsRouter() {
  return router;
}
