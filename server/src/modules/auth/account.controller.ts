import type { NextFunction, Request, Response } from 'express';
import { UnauthorizedError } from '../../shared/errors.js';
import type { AuthUser } from './auth.types.js';
import * as accountService from './account.service.js';
import { adminUserListSchema } from './auth.schema.js';

function currentUser(req: Request): AuthUser {
  const user = req.user as AuthUser | undefined;
  if (!user) throw new UnauthorizedError();
  return user;
}

export async function getProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.getAccountProfile(currentUser(req).id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function updateProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.updateAccountProfile(currentUser(req).id, req.body);
    res.json({ success: true, message: 'Profile updated successfully', data });
  } catch (error) {
    next(error);
  }
}

export async function getConnectedAccounts(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.getConnectedAccounts(currentUser(req).id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function getPreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json({ success: true, data: await accountService.getAccountPreferences(currentUser(req).id) });
  } catch (error) {
    next(error);
  }
}

export async function updatePreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.updateAccountPreferences(currentUser(req).id, req.body);
    res.json({ success: true, message: 'Preferences saved successfully', data });
  } catch (error) {
    next(error);
  }
}

export async function getPrivacyPreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json({ success: true, data: await accountService.getPrivacyPreferences(currentUser(req).id) });
  } catch (error) {
    next(error);
  }
}

export async function updatePrivacyPreferences(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.updatePrivacyPreferences(currentUser(req).id, req.body);
    res.json({ success: true, message: 'Privacy preferences saved successfully', data });
  } catch (error) {
    next(error);
  }
}

export async function exportAccountData(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.exportAccountData(currentUser(req).id);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function requestEmailChange(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.requestEmailChange(currentUser(req).id, req.body.newEmail);
    res.json({ success: true, message: 'If the address is available, a verification email has been sent' });
  } catch (error) {
    next(error);
  }
}

export async function confirmEmailChange(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.confirmEmailChange(currentUser(req).id, req.body.token);
    res.json({ success: true, message: 'Email address updated successfully' });
  } catch (error) {
    next(error);
  }
}

export async function requestPhoneChange(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.requestPhoneChange(currentUser(req).id, req.body.newPhone);
    res.json({ success: true, message: 'If the number is available, a verification code has been sent' });
  } catch (error) {
    next(error);
  }
}

export async function confirmPhoneChange(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.confirmPhoneChange(currentUser(req).id, req.body.otp);
    res.json({ success: true, message: 'Phone number updated successfully' });
  } catch (error) {
    next(error);
  }
}

export async function getSuspensionDetails(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json({ success: true, data: await accountService.getAccountStatusDetails(currentUser(req).id, 'suspended') });
  } catch (error) {
    next(error);
  }
}

export async function getLockDetails(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json({ success: true, data: await accountService.getAccountStatusDetails(currentUser(req).id, 'locked') });
  } catch (error) {
    next(error);
  }
}

export async function changePassword(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = currentUser(req);
    await accountService.changePassword(
      user.id,
      req.body.currentPassword,
      req.body.newPassword,
    );
    res.json({ success: true, message: 'Password changed; sign in again' });
  } catch (error) {
    next(error);
  }
}

export async function pauseAccount(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.pauseAccount(currentUser(req), req.body.currentPassword);
    res.json({ success: true, message: 'Account paused' });
  } catch (error) {
    next(error);
  }
}

export async function deleteAccount(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.deleteAccount(currentUser(req), req.body.currentPassword);
    res.json({ success: true, message: 'Account deletion completed' });
  } catch (error) {
    next(error);
  }
}

export async function requestAccountRestorationByEmail(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.requestAccountRestoration(req.body.email);
    res.json({ success: true, message: 'If the account is eligible, restoration instructions have been sent' });
  } catch (error) {
    next(error);
  }
}

export async function requestAccountRestorationByPhone(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.requestAccountRestoration(req.body.phone);
    res.json({ success: true, message: 'If the account is eligible, restoration instructions have been sent' });
  } catch (error) {
    next(error);
  }
}

export async function confirmAccountRestoration(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await accountService.confirmAccountRestoration(req.body.token);
    res.json({ success: true, message: 'Account restored. Sign in to continue.' });
  } catch (error) {
    next(error);
  }
}

export async function listUsers(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.listUsers(adminUserListSchema.parse(req.query));
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function getUser(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.getUserForAdmin(req.params.targetUserId as string);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
}

export async function updateUserStatus(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await accountService.updateUserStatus(
      currentUser(req),
      req.params.targetUserId as string,
      req.body.action,
      req.body.reason,
    );
    res.json({ success: true, message: 'Account status updated', data });
  } catch (error) {
    next(error);
  }
}
