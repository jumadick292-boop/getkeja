import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requireFreshMfaVerification } from './auth.middleware.js';
import { requirePermission } from './authorization.middleware.js';
import {
  accountDataExportRateLimiter,
  loginIpRateLimiter,
  loginOtpRequestRateLimiter,
} from '../../middleware/rate-limit.js';
import * as controller from './account.controller.js';
import {
  adminUserIdParamsSchema,
  adminUserListSchema,
  adminUserStatusSchema,
  accountPreferencesSchema,
  accountRestoreEmailRequestSchema,
  accountRestorePhoneRequestSchema,
  accountRestoreVerifySchema,
  changePasswordSchema,
  deleteAccountSchema,
  emailChangeConfirmSchema,
  emailChangeRequestSchema,
  pauseAccountSchema,
  phoneChangeConfirmSchema,
  phoneChangeRequestSchema,
  privacyPreferencesSchema,
  updateAccountProfileSchema,
} from './auth.schema.js';

const router = Router();

router.get('/account/profile', requireAuth, controller.getProfile);
router.patch('/account/profile', requireAuth, validate(updateAccountProfileSchema), controller.updateProfile);
router.get('/account/connected-accounts', requireAuth, controller.getConnectedAccounts);
router.get('/account/preferences', requireAuth, controller.getPreferences);
router.patch('/account/preferences', requireAuth, validate(accountPreferencesSchema), controller.updatePreferences);
router.get('/account/privacy', requireAuth, controller.getPrivacyPreferences);
router.patch('/account/privacy', requireAuth, validate(privacyPreferencesSchema), controller.updatePrivacyPreferences);
router.post(
  '/account/data-export',
  requireAuth,
  accountDataExportRateLimiter(),
  controller.exportAccountData,
);
router.post(
  '/account/email/change-request',
  requireAuth,
  loginOtpRequestRateLimiter('email'),
  validate(emailChangeRequestSchema),
  controller.requestEmailChange,
);
router.post('/account/email/change-confirm', requireAuth, validate(emailChangeConfirmSchema), controller.confirmEmailChange);
router.post(
  '/account/phone/change-request',
  requireAuth,
  loginOtpRequestRateLimiter('phone'),
  validate(phoneChangeRequestSchema),
  controller.requestPhoneChange,
);
router.post('/account/phone/change-confirm', requireAuth, validate(phoneChangeConfirmSchema), controller.confirmPhoneChange);
router.get('/account/status/suspension', requireAuth, controller.getSuspensionDetails);
router.get('/account/status/lock', requireAuth, controller.getLockDetails);
router.post(
  '/account/password/change',
  requireAuth,
  requireFreshMfaVerification,
  validate(changePasswordSchema),
  controller.changePassword,
);
router.post(
  '/account/pause',
  requireAuth,
  requireFreshMfaVerification,
  validate(pauseAccountSchema),
  controller.pauseAccount,
);
router.delete(
  '/account',
  requireAuth,
  requireFreshMfaVerification,
  validate(deleteAccountSchema),
  controller.deleteAccount,
);
router.post(
  '/account/restore/email/request',
  loginOtpRequestRateLimiter('email'),
  validate(accountRestoreEmailRequestSchema),
  controller.requestAccountRestorationByEmail,
);
router.post(
  '/account/restore/phone/request',
  loginOtpRequestRateLimiter('phone'),
  validate(accountRestorePhoneRequestSchema),
  controller.requestAccountRestorationByPhone,
);
router.post(
  '/account/restore/confirm',
  loginIpRateLimiter(),
  validate(accountRestoreVerifySchema),
  controller.confirmAccountRestoration,
);

router.get(
  '/admin/users',
  requirePermission('admin.users.view'),
  validate(adminUserListSchema, 'query'),
  controller.listUsers,
);
router.get(
  '/admin/users/:targetUserId',
  requirePermission('admin.users.view'),
  validate(adminUserIdParamsSchema, 'params'),
  controller.getUser,
);
router.patch(
  '/admin/users/:targetUserId/status',
  requirePermission('admin.users.suspend'),
  validate(adminUserIdParamsSchema, 'params'),
  validate(adminUserStatusSchema),
  controller.updateUserStatus,
);

export default router;
