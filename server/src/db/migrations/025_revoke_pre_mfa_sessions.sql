-- Migration: 025_revoke_pre_mfa_sessions
-- Description: Revoke sessions issued before the MFA handoff was enforced

DELETE FROM auth_sessions;
