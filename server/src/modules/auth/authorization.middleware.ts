import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { UnauthorizedError, ForbiddenError } from '../../shared/errors.js';
import * as sessionService from './session.service.js';
import * as authz from './authorization.service.js';
import type { AuthorizationContext } from './auth.types.js';

function getAccessToken(req: Request): string | undefined {
  const authHeader = req.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    return authHeader.slice(7);
  }
  return req.get('x-access-token') as string | undefined;
}

async function validateTokenAndGetContext(req: Request): Promise<{ userId: string; sessionId: string } | null> {
  const accessToken = getAccessToken(req);
  if (!accessToken) return null;

  const result = await sessionService.validateAccessToken(accessToken);
  if (!result) return null;

  req.user = result.user;
  req.session = result.session;

  return { userId: result.user.id, sessionId: result.session.id };
}

export const requireAuthenticatedUser: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }
    next();
  } catch (error) {
    next(error);
  }
};

export const requireActiveAccount: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const user = req.user!;
    if (!user.isActive || user.isSuspended || user.isLocked || user.isDeactivated) {
      throw new ForbiddenError(`Account ${user.accountStatus}`);
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const requireMfaEnrollment: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const user = req.user!;
    if (!user.mfaEnrolledAt) {
      throw new ForbiddenError('MFA enrollment is required to access this resource');
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const requireFreshMfaVerification: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const user = req.user!;
    if (!user.mfaEnrolledAt) {
      throw new ForbiddenError('MFA enrollment is required');
    }

    if (user.lastMfaVerifiedAt) {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      if (user.lastMfaVerifiedAt < fiveMinutesAgo) {
        throw new ForbiddenError('Fresh MFA verification required for this operation');
      }
    } else {
      throw new ForbiddenError('MFA verification required for this operation');
    }

    next();
  } catch (error) {
    next(error);
  }
};

export const requirePlatformRole = (roleId: string): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const hasRole = await authz.hasPlatformRole(context.userId, roleId);
      if (!hasRole) {
        throw new ForbiddenError(`Platform role '${roleId}' required`);
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requireSystemRole: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const hasSystemRole = await authz.hasSystemRole(context.userId);
    if (!hasSystemRole) {
      throw new ForbiddenError('System administrator access required');
    }

    next();
  } catch (error) {
    next(error);
  }
};

function getParamValue(req: Request, param: string): string | undefined {
  const value = req.params[param];
  return Array.isArray(value) ? value[0] : value;
}

export const requireOrganizationMembership = (organizationIdParam: string = 'organizationId'): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const organizationId = getParamValue(req, organizationIdParam) || req.body[organizationIdParam] || req.query[organizationIdParam];
      if (!organizationId) {
        throw new ForbiddenError('Organization ID required');
      }

      const isMember = await authz.isOrganizationMember(context.userId, organizationId);
      if (!isMember) {
        throw new ForbiddenError('Organization membership required');
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requireOrganizationRole = (role: string, organizationIdParam: string = 'organizationId'): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const organizationId = getParamValue(req, organizationIdParam) || req.body[organizationIdParam] || req.query[organizationIdParam];
      if (!organizationId) {
        throw new ForbiddenError('Organization ID required');
      }

      const orgRoleIds = await authz.getUserOrganizationRoleIds(context.userId, organizationId);
      if (!orgRoleIds.includes(role)) {
        throw new ForbiddenError(`Organization role '${role}' required`);
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requirePermission = (
  permission: string,
  resourceContext?: {
    resourceTypeParam?: string;
    resourceIdParam?: string;
    organizationIdParam?: string;
  }
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const authzContext: AuthorizationContext = {
        userId: context.userId,
        sessionId: context.sessionId,
        permission,
        resourceType: resourceContext?.resourceTypeParam ? getParamValue(req, resourceContext.resourceTypeParam) : undefined,
        resourceId: resourceContext?.resourceIdParam ? getParamValue(req, resourceContext.resourceIdParam) : undefined,
        organizationId: resourceContext?.organizationIdParam ? getParamValue(req, resourceContext.organizationIdParam) : undefined,
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      };

      const decision = await authz.authorize(authzContext);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      // Attach authorization decision to request for downstream use
      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requireAnyPermission = (
  permissions: string[],
  resourceContext?: {
    resourceTypeParam?: string;
    resourceIdParam?: string;
    organizationIdParam?: string;
  }
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const hasAny = await authz.hasAnyPermission(context.userId, permissions);
      if (!hasAny) {
        throw new ForbiddenError(`One of the following permissions required: ${permissions.join(', ')}`);
      }

      // Also check resource-level access if context provided
      if (resourceContext?.resourceTypeParam && resourceContext?.resourceIdParam) {
        for (const permission of permissions) {
          const authzContext: AuthorizationContext = {
            userId: context.userId,
            sessionId: context.sessionId,
            permission,
            resourceType: getParamValue(req, resourceContext.resourceTypeParam),
            resourceId: getParamValue(req, resourceContext.resourceIdParam),
            organizationId: resourceContext.organizationIdParam ? getParamValue(req, resourceContext.organizationIdParam) : undefined,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
          };

          const decision = await authz.authorize(authzContext);
          if (decision.allowed) {
            (req as any).authorization = decision;
            return next();
          }
        }
        throw new ForbiddenError('Resource access denied');
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requireAllPermissions = (
  permissions: string[],
  resourceContext?: {
    resourceTypeParam?: string;
    resourceIdParam?: string;
    organizationIdParam?: string;
  }
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const hasAll = await authz.hasAllPermissions(context.userId, permissions);
      if (!hasAll) {
        throw new ForbiddenError(`All of the following permissions required: ${permissions.join(', ')}`);
      }

      // Check resource-level access for all permissions
      if (resourceContext?.resourceTypeParam && resourceContext?.resourceIdParam) {
        for (const permission of permissions) {
          const authzContext: AuthorizationContext = {
            userId: context.userId,
            sessionId: context.sessionId,
            permission,
            resourceType: getParamValue(req, resourceContext.resourceTypeParam),
            resourceId: getParamValue(req, resourceContext.resourceIdParam),
            organizationId: resourceContext.organizationIdParam ? getParamValue(req, resourceContext.organizationIdParam) : undefined,
            ipAddress: req.ip,
            userAgent: req.get('user-agent'),
          };

          const decision = await authz.authorize(authzContext);
          if (!decision.allowed) {
            throw new ForbiddenError(`Resource access denied for permission: ${permission}`);
          }
        }
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requireRecentMfa: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const user = req.user!;
    if (!user.mfaEnrolledAt) {
      throw new ForbiddenError('MFA enrollment is required');
    }

    if (user.lastMfaVerifiedAt) {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      if (user.lastMfaVerifiedAt < fiveMinutesAgo) {
        throw new ForbiddenError('Fresh MFA verification required for this operation');
      }
    } else {
      throw new ForbiddenError('MFA verification required for this operation');
    }

    next();
  } catch (error) {
    next(error);
  }
};

// Optional auth - doesn't throw if not authenticated
export const optionalAuth: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    await validateTokenAndGetContext(req);
    next();
  } catch {
    next();
  }
};

// Alias for backward compatibility
export const requireAuth = requireAuthenticatedUser;

/**
 * Middleware to require access to a specific property
 */
export const requirePropertyAccess = (
  propertyIdParam: string = 'propertyId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const propertyId = getParamValue(req, propertyIdParam) || req.body[propertyIdParam] || req.query[propertyIdParam];
      if (!propertyId) {
        throw new ForbiddenError('Property ID required');
      }

      const decision = await authz.canAccessProperty(context.userId, propertyId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Middleware to require access to a specific unit
 */
export const requireUnitAccess = (
  unitIdParam: string = 'unitId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const unitId = getParamValue(req, unitIdParam) || req.body[unitIdParam] || req.query[unitIdParam];
      if (!unitId) {
        throw new ForbiddenError('Unit ID required');
      }

      const decision = await authz.canAccessUnit(context.userId, unitId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Middleware to require access to a specific tenancy
 */
export const requireTenancyAccess = (
  tenancyIdParam: string = 'tenancyId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const tenancyId = getParamValue(req, tenancyIdParam) || req.body[tenancyIdParam] || req.query[tenancyIdParam];
      if (!tenancyId) {
        throw new ForbiddenError('Tenancy ID required');
      }

      const decision = await authz.canAccessTenancy(context.userId, tenancyId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Middleware to require access to a specific property document
 */
export const requireDocumentAccess = (
  documentIdParam: string = 'documentId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const documentId = getParamValue(req, documentIdParam) || req.body[documentIdParam] || req.query[documentIdParam];
      if (!documentId) {
        throw new ForbiddenError('Document ID required');
      }

      const decision = await authz.canAccessPropertyDocument(context.userId, documentId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Middleware to require access to a specific site visit
 */
export const requireSiteVisitAccess = (
  visitIdParam: string = 'visitId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const visitId = getParamValue(req, visitIdParam) || req.body[visitIdParam] || req.query[visitIdParam];
      if (!visitId) {
        throw new ForbiddenError('Site visit ID required');
      }

      const decision = await authz.canAccessSiteVisit(context.userId, visitId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Middleware that restricts site-visit management (create/update/delete on the
 * generic resource router) to users who can manage the target property.
 * House Seekers must use the house-seeker site visit endpoints instead.
 */
export const requireSiteVisitManager: RequestHandler = async (
  req: Request,
  _res: Response,
  next: NextFunction,
) => {
  try {
    const context = await validateTokenAndGetContext(req);
    if (!context) {
      throw new UnauthorizedError();
    }

    const visitId = getParamValue(req, 'visitId');
    const propertyId = (req.body?.propertyId ?? req.query?.propertyId) as string | undefined;

    if (visitId) {
      const result = await authz.canManageAnySiteVisit(context.userId, visitId);
      if (!result.allowed) {
        throw new ForbiddenError(result.reason);
      }
      next();
      return;
    }

    if (!propertyId) {
      throw new ForbiddenError('propertyId is required');
    }

    const decision = await authz.canAccessProperty(context.userId, propertyId, 'property.manage');
    if (!decision.allowed) {
      throw new ForbiddenError(decision.reason);
    }
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Middleware to require access to a specific rental application
 */
export const requireRentalApplicationAccess = (
  applicationIdParam: string = 'applicationId',
  requiredPermission?: string
): RequestHandler => {
  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const context = await validateTokenAndGetContext(req);
      if (!context) {
        throw new UnauthorizedError();
      }

      const applicationId = getParamValue(req, applicationIdParam) || req.body[applicationIdParam] || req.query[applicationIdParam];
      if (!applicationId) {
        throw new ForbiddenError('Rental application ID required');
      }

      const decision = await authz.canAccessRentalApplication(context.userId, applicationId, requiredPermission);

      if (!decision.allowed) {
        throw new ForbiddenError(decision.reason);
      }

      (req as any).authorization = decision;
      next();
    } catch (error) {
      next(error);
    }
  };
};