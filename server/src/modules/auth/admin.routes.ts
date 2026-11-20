import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePermission } from './authorization.middleware.js';
import * as adminController from './admin.controller.js';
import * as authSchema from './auth.schema.js';

const router = Router();

// All routes require authentication and admin permissions
router.use(requireAuth);
router.use(requirePermission('admin.roles.manage'));

// Roles
router.get('/roles', adminController.getRoles);
router.post('/roles', validate(authSchema.createRoleSchema), adminController.createRole);
router.patch('/roles/:roleId', validate(authSchema.updateRoleSchema), adminController.updateRole);
router.delete('/roles/:roleId', adminController.deleteRole);
router.get('/roles/:roleId/permissions', adminController.getRolePermissions);
router.post('/roles/:roleId/permissions/:permissionId', adminController.assignPermissionToRole);
router.delete('/roles/:roleId/permissions/:permissionId', adminController.removePermissionFromRole);
router.put('/roles/:roleId/permissions', adminController.setRolePermissions);

// Permissions
router.get('/permissions', adminController.getPermissions);
router.post('/permissions', validate(authSchema.createPermissionSchema), adminController.createPermission);

// User role assignments
router.post('/users/:targetUserId/roles', validate(authSchema.assignRoleToUserSchema), adminController.assignRoleToUser);
router.delete('/users/:targetUserId/roles/:assignmentId', adminController.removeRoleFromUser);

// Audit
router.get('/audit', validate(authSchema.auditQuerySchema), adminController.getAuthorizationAudit);

export default router;