import type { Request, Response, NextFunction } from 'express';
import * as repo from './auth.repository.js';
import { ForbiddenError, NotFoundError, ConflictError } from '../../shared/errors.js';
import * as authz from './authorization.service.js';

function getParamValue(req: Request, param: string): string | undefined {
  const value = req.params[param];
  return Array.isArray(value) ? value[0] : value;
}

export async function getRoles(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const roles = await repo.getAllRoles();
    res.json({ roles });
  } catch (error) {
    next(error);
  }
}

export async function createRole(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;

    // Check if user has permission to manage roles
    const hasPermission = await authz.hasPermission(userId, 'admin.roles.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to create roles');
    }

    const { id, name, description, isSystem, isPubliclyAssignable } = req.body;

    if (!id || !name) {
      throw new Error('Role ID and name are required');
    }

    // Prevent creating system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can create system roles');
    }

    const existing = await repo.getRoleById(id);
    if (existing) {
      throw new ConflictError('Role already exists');
    }

    const role = await repo.createRole({ id, name, description, isSystem, isPubliclyAssignable });
    res.status(201).json({ role });
  } catch (error) {
    next(error);
  }
}

export async function updateRole(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const roleId = getParamValue(req, 'roleId')!;

    const hasPermission = await authz.hasPermission(userId, 'admin.roles.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to update roles');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    // Prevent modifying system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can modify system roles');
    }

    const { name, description, isPubliclyAssignable } = req.body;
    const updated = await repo.updateRole(roleId, { name, description, isPubliclyAssignable });

    if (!updated) {
      throw new NotFoundError('Role not found');
    }

    res.json({ role: updated });
  } catch (error) {
    next(error);
  }
}

export async function deleteRole(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const roleId = getParamValue(req, 'roleId')!;

    const hasPermission = await authz.hasPermission(userId, 'admin.roles.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to delete roles');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    // Prevent deleting system roles
    if (role.isSystem) {
      throw new ForbiddenError('Cannot delete system roles');
    }

    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (!isSuperAdmin) {
      // Check if role is assigned to any users
      const assignments = await repo.getRoleAssignmentsByOrganization(''); // We need a different check
      // For now, just prevent deletion if not super_admin
      throw new ForbiddenError('Only super administrators can delete roles');
    }

    const deleted = await repo.deleteRole(roleId);
    if (!deleted) {
      throw new NotFoundError('Role not found');
    }

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function createPermission(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;

    const hasPermission = await authz.hasPermission(userId, 'admin.permissions.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to create permissions');
    }

    const { id, name, description, category, isSystem } = req.body;

    if (!id || !name || !category) {
      throw new Error('Permission ID, name, and category are required');
    }

    // Prevent creating system permissions unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can create system permissions');
    }

    const existing = await repo.getPermissionById(id);
    if (existing) {
      throw new ConflictError('Permission already exists');
    }

    const permission = await repo.createPermission({ id, name, description, category, isSystem });
    res.status(201).json({ permission });
  } catch (error) {
    next(error);
  }
}

export async function getPermissions(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const permissions = await repo.getAllPermissions();
    res.json({ permissions });
  } catch (error) {
    next(error);
  }
}

export async function getRolePermissions(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const roleId = getParamValue(req, 'roleId')!;
    const permissions = await repo.getRolePermissions(roleId);
    res.json({ permissions });
  } catch (error) {
    next(error);
  }
}

export async function assignPermissionToRole(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const roleId = getParamValue(req, 'roleId')!;
    const permissionId = getParamValue(req, 'permissionId')!;

    const hasPermission = await authz.hasPermission(userId, 'admin.permissions.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to manage role permissions');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    const permission = await repo.getPermissionById(permissionId);
    if (!permission) {
      throw new NotFoundError('Permission not found');
    }

    // Prevent assigning system permissions to non-system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (permission.isSystem && !role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Cannot assign system permissions to non-system roles');
    }

    await repo.assignPermissionToRole(roleId, permissionId);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function removePermissionFromRole(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const roleId = getParamValue(req, 'roleId')!;
    const permissionId = getParamValue(req, 'permissionId')!;

    const hasPermission = await authz.hasPermission(userId, 'admin.permissions.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to manage role permissions');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    // Prevent removing system permissions from system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can modify system role permissions');
    }

    await repo.removePermissionFromRole(roleId, permissionId);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function setRolePermissions(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const roleId = getParamValue(req, 'roleId')!;
    const { permissionIds } = req.body;

    const hasPermission = await authz.hasPermission(userId, 'admin.permissions.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to manage role permissions');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can modify system role permissions');
    }

    // Validate all permissions exist
    for (const permissionId of permissionIds) {
      const permission = await repo.getPermissionById(permissionId);
      if (!permission) {
        throw new NotFoundError(`Permission not found: ${permissionId}`);
      }
      if (permission.isSystem && !role.isSystem && !isSuperAdmin) {
        throw new ForbiddenError(`Cannot assign system permission ${permissionId} to non-system role`);
      }
    }

    await repo.setRolePermissions(roleId, permissionIds);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function assignRoleToUser(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const targetUserId = getParamValue(req, 'targetUserId')!;
    const { roleId, scope, organizationId, resourceType, resourceId, expiresAt } = req.body;

    const hasPermission = await authz.hasPermission(userId, 'admin.roles.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to assign roles');
    }

    const role = await repo.getRoleById(roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    // Prevent assigning system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can assign system roles');
    }

    // Prevent assigning organization_owner role unless super_admin or organization owner
    if (roleId === 'organization_owner') {
      if (!isSuperAdmin) {
        const isOrgOwner = await authz.isOrganizationOwner(userId, organizationId!);
        if (!isOrgOwner) {
          throw new ForbiddenError('Only organization owners can assign owner role');
        }
      }
    }

    const assignment = await repo.createRoleAssignment({
      userId: targetUserId,
      roleId,
      scope: scope || 'global',
      organizationId,
      resourceType,
      resourceId,
      assignedBy: userId,
      expiresAt: expiresAt ? new Date(expiresAt) : null,
    });

    await authz.invalidateUserPermissionCache(targetUserId);

    res.status(201).json({ assignment });
  } catch (error) {
    next(error);
  }
}

export async function removeRoleFromUser(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;
    const targetUserId = getParamValue(req, 'targetUserId')!;
    const assignmentId = getParamValue(req, 'assignmentId')!;

    const hasPermission = await authz.hasPermission(userId, 'admin.roles.manage');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to remove roles');
    }

    const assignment = await repo.getRoleAssignmentById(assignmentId);
    if (!assignment) {
      throw new NotFoundError('Role assignment not found');
    }

    if (assignment.userId !== targetUserId) {
      throw new ForbiddenError('Assignment does not belong to specified user');
    }

    const role = await repo.getRoleById(assignment.roleId);
    if (!role) {
      throw new NotFoundError('Role not found');
    }

    // Prevent removing system roles unless super_admin
    const isSuperAdmin = await authz.hasPlatformRole(userId, 'super_admin');
    if (role.isSystem && !isSuperAdmin) {
      throw new ForbiddenError('Only super administrators can remove system roles');
    }

    await repo.revokeRoleAssignment(assignmentId, userId, 'Removed by administrator');
    await authz.invalidateUserPermissionCache(targetUserId);

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
}

export async function getAuthorizationAudit(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  try {
    const userId = req.user!.id;

    const hasPermission = await authz.hasPermission(userId, 'admin.audit.view');
    if (!hasPermission) {
      throw new ForbiddenError('Insufficient permissions to view audit logs');
    }

    const filters = {
      userId: req.query.userId as string,
      sessionId: req.query.sessionId as string,
      decision: req.query.decision as 'allow' | 'deny',
      permissionId: req.query.permissionId as string,
      resourceType: req.query.resourceType as string,
      resourceId: req.query.resourceId as string,
      organizationId: req.query.organizationId as string,
      fromDate: req.query.fromDate ? new Date(req.query.fromDate as string) : undefined,
      toDate: req.query.toDate ? new Date(req.query.toDate as string) : undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 50,
      offset: req.query.offset ? parseInt(req.query.offset as string, 10) : 0,
    };

    const events = await repo.getAuthorizationAuditEvents(filters);
    res.json({ events });
  } catch (error) {
    next(error);
  }
}