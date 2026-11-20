import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import {
  confirmEmailVerificationSchema,
  confirmPhoneVerificationSchema,
  forgotPasswordSchema,
  googleAuthSchema,
  googleRegistrationSchema,
  googleLinkSchema,
  googleUnlinkSchema,
  loginPhoneSchema,
  loginSchema,
  registerEmailSchema,
  registerPhoneOtpSchema,
  registerPhoneSchema,
  requestEmailVerificationSchema,
  requestPhoneVerificationSchema,
  resetPasswordSchema,
  setPasswordSchema,
  requestEmailLoginOtpSchema,
  verifyEmailLoginOtpSchema,
  requestPhoneLoginOtpSchema,
  verifyPhoneLoginOtpSchema,
  mfaChallengeSchema,
  verifyMfaSchema,
  mfaEnrollmentStartSchema,
  mfaEnrollmentVerifySchema,
  mfaEnrollmentCodeRequestSchema,
  mfaChallengeCodeRequestSchema,
  mfaMethodDisableSchema,
  mfaMethodSetPrimarySchema,
  mfaRecoveryCodesRegenerateSchema,
  accountRecoveryRequestSchema,
  accountRecoveryPhoneSchema,
  accountRecoveryVerifySchema,
} from './auth.schema.js';
import {
  confirmEmailVerification,
  confirmPhoneVerification,
  forgotPassword,
  getCurrentUser,
  googleAuth,
  googleCallback,
  googleAuthLogin,
  linkGoogle,
  login,
  loginWithEmail,
  loginWithPhone,
  logout,
  registerEmail,
  registerGoogle,
  registerPhone,
  registerPhoneOtp,
  requestEmailVerification,
  requestPhoneVerification,
  requestEmailLoginOtp,
  verifyEmailLoginOtp,
  requestPhoneLoginOtp,
  verifyPhoneLoginOtp,
  resetPassword,
  setPassword,
  unlinkGoogle,
  getMfaChallenge,
  verifyMfa,
} from './auth.controller.js';
import {
  mfaEnrollmentStart,
  mfaEnrollmentVerify,
  mfaEnrollmentRequestCode,
  mfaMethodRequestCode,
  mfaEnrollmentSkip,
  mfaStatus,
  mfaMethods,
  mfaChallengeCreate,
  mfaChallengeVerify,
  mfaChallengeRequestCode,
  mfaAddMethod,
  mfaVerifyMethod,
  mfaDisableMethod,
  mfaSetPrimaryMethod,
  mfaRegenerateRecoveryCodes,
} from './mfa/mfa.controller.js';
import {
  accountRecoveryRequest,
  accountRecoveryPhone,
  accountRecoveryVerify,
  getSecurityEvents,
} from './recovery.controller.js';
import { requireAuth, requireMfaEnrollmentOrAuth } from './auth.middleware.js';
import organisationRoutes from './organisation.routes.js';
import adminRoutes from './admin.routes.js';
import { createResourceRouter } from './resource.routes.js';
import notificationRoutes from './notification.routes.js';
import { createSessionRouter } from './session.routes.js';
import accountRoutes from './account.routes.js';
import {
  loginEmailRateLimiter,
  loginPhoneRateLimiter,
  loginOtpRequestRateLimiter,
  loginOtpVerifyRateLimiter,
  loginGoogleRateLimiter,
  loginIpRateLimiter,
  registrationRateLimiter,
} from '../../middleware/rate-limit.js';

export function createAuthRouter(nodeEnv: 'development' | 'test' | 'production'): Router {
  const router = Router();

  router.use('/login', loginIpRateLimiter());
  router.use('/google', loginIpRateLimiter());

  router.post('/register/email', registrationRateLimiter('email'), validate(registerEmailSchema), registerEmail);
  router.post('/register/phone', registrationRateLimiter('phone'), validate(registerPhoneSchema), registerPhone);
  router.post('/register/phone-otp', registrationRateLimiter('phone'), validate(registerPhoneOtpSchema), registerPhoneOtp);
  router.post('/register/google', loginGoogleRateLimiter(), validate(googleRegistrationSchema), registerGoogle);

  router.post('/login', loginEmailRateLimiter(), validate(loginSchema), loginWithEmail);
  router.post('/login/email', loginEmailRateLimiter(), validate(loginSchema), loginWithEmail);
  router.post('/login/phone', loginPhoneRateLimiter(), validate(loginPhoneSchema), loginWithPhone);
  router.post('/login/email/otp/request', loginOtpRequestRateLimiter('email'), validate(requestEmailLoginOtpSchema), requestEmailLoginOtp);
  router.post('/login/email/otp/verify', loginOtpVerifyRateLimiter('email'), validate(verifyEmailLoginOtpSchema), verifyEmailLoginOtp);
  router.post('/login/phone/otp/request', loginOtpRequestRateLimiter('phone'), validate(requestPhoneLoginOtpSchema), requestPhoneLoginOtp);
  router.post('/login/phone/otp/verify', loginOtpVerifyRateLimiter('phone'), validate(verifyPhoneLoginOtpSchema), verifyPhoneLoginOtp);
  router.post('/login/email-otp/request', loginOtpRequestRateLimiter('email'), validate(requestEmailLoginOtpSchema), requestEmailLoginOtp);
  router.post('/login/email-otp/verify', loginOtpVerifyRateLimiter('email'), validate(verifyEmailLoginOtpSchema), verifyEmailLoginOtp);
  router.post('/login/phone-otp/request', loginOtpRequestRateLimiter('phone'), validate(requestPhoneLoginOtpSchema), requestPhoneLoginOtp);
  router.post('/login/phone-otp/verify', loginOtpVerifyRateLimiter('phone'), validate(verifyPhoneLoginOtpSchema), verifyPhoneLoginOtp);
  router.post('/login/google', loginGoogleRateLimiter(), validate(googleAuthSchema), googleAuthLogin);

  router.post('/mfa/verify', loginIpRateLimiter(), validate(verifyMfaSchema), verifyMfa);
  router.post('/mfa/challenge', loginIpRateLimiter(), validate(mfaChallengeSchema), getMfaChallenge);
  router.post('/mfa/challenge/request-code', loginIpRateLimiter(), validate(mfaChallengeCodeRequestSchema), mfaChallengeRequestCode);

  // MFA Enrollment
  router.post('/mfa/enrollment/start', loginIpRateLimiter(), requireMfaEnrollmentOrAuth, validate(mfaEnrollmentStartSchema), mfaEnrollmentStart);
  router.post('/mfa/enrollment/verify', loginIpRateLimiter(), requireMfaEnrollmentOrAuth, validate(mfaEnrollmentVerifySchema), mfaEnrollmentVerify);
  router.post('/mfa/enrollment/request-code', loginIpRateLimiter(), requireMfaEnrollmentOrAuth, validate(mfaEnrollmentCodeRequestSchema), mfaEnrollmentRequestCode);
  router.post('/mfa/enrollment/skip', requireMfaEnrollmentOrAuth, mfaEnrollmentSkip);
  router.get('/mfa/status', requireAuth, mfaStatus);
  router.get('/mfa/methods', requireAuth, mfaMethods);

  // MFA Login Challenge
  router.post('/mfa/challenge/verify', requireAuth, validate(mfaEnrollmentVerifySchema), mfaChallengeVerify);

  // MFA Management
  router.post('/mfa/methods/add', loginIpRateLimiter(), requireAuth, validate(mfaEnrollmentStartSchema), mfaAddMethod);
  router.post('/mfa/methods/request-code', loginIpRateLimiter(), requireAuth, validate(mfaEnrollmentCodeRequestSchema), mfaMethodRequestCode);
  router.post('/mfa/methods/verify', loginIpRateLimiter(), requireAuth, validate(mfaEnrollmentVerifySchema), mfaVerifyMethod);
  router.post('/mfa/methods/disable', loginIpRateLimiter(), requireAuth, validate(mfaMethodDisableSchema), mfaDisableMethod);
  router.post('/mfa/methods/set-primary', loginIpRateLimiter(), requireAuth, validate(mfaMethodSetPrimarySchema), mfaSetPrimaryMethod);
  router.post('/mfa/recovery-codes/regenerate', loginIpRateLimiter(), requireAuth, validate(mfaRecoveryCodesRegenerateSchema), mfaRegenerateRecoveryCodes);

  router.post('/logout', logout);
  router.get('/me', getCurrentUser);

  router.post('/forgot-password', loginOtpRequestRateLimiter('email'), validate(forgotPasswordSchema), forgotPassword(nodeEnv));
  router.post('/reset-password', loginIpRateLimiter(), validate(resetPasswordSchema), resetPassword);

  router.post('/verify-email/request', loginOtpRequestRateLimiter('email'), validate(requestEmailVerificationSchema), requestEmailVerification);
  router.post('/verify-email/confirm', loginOtpVerifyRateLimiter('email'), validate(confirmEmailVerificationSchema), confirmEmailVerification);

  router.post('/verify-phone/request', loginOtpRequestRateLimiter('phone'), validate(requestPhoneVerificationSchema), requestPhoneVerification);
  router.post('/verify-phone/confirm', loginOtpVerifyRateLimiter('phone'), validate(confirmPhoneVerificationSchema), confirmPhoneVerification);

  router.get('/google', loginGoogleRateLimiter(), googleAuth);
  router.get('/google/callback', loginGoogleRateLimiter(), googleCallback);

  router.post('/google/link', requireAuth, validate(googleLinkSchema), linkGoogle);
  router.delete('/google/unlink', requireAuth, validate(googleUnlinkSchema), unlinkGoogle);

  router.post('/set-password', requireAuth, validate(setPasswordSchema), setPassword);

  router.use(accountRoutes);

  // Account Recovery
  router.post('/account/recovery/request', loginOtpRequestRateLimiter('email'), validate(accountRecoveryRequestSchema), accountRecoveryRequest);
  router.post('/account/recovery/phone', loginOtpRequestRateLimiter('phone'), validate(accountRecoveryPhoneSchema), accountRecoveryPhone);
  router.post('/account/recovery/verify', loginIpRateLimiter(), validate(accountRecoveryVerifySchema), accountRecoveryVerify);
  router.get('/security-events', requireAuth, getSecurityEvents);

  router.use(createSessionRouter());

  // Organisations
  router.use('/organisations', organisationRoutes);

  // Admin
  router.use('/admin', adminRoutes);

  // Resources
  router.use('/', createResourceRouter());

  // Notifications
  router.use('/notifications', notificationRoutes);

  return router;
}
