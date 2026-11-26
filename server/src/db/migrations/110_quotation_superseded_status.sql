-- Migration: 110_quotation_superseded_status
-- Description: Task 13.5 — add a terminal 'superseded' status to
--   service_quotation_status so a revised quotation can leave the live set
--   (submitted/revised) before its replacement version is inserted. This keeps
--   the partial unique index (one live quotation per provider per request)
--   intact across revisions. Enum-only change; additive and idempotent.

ALTER TYPE service_quotation_status ADD VALUE IF NOT EXISTS 'superseded';