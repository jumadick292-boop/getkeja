import { z } from 'zod';

const conversationTypeSchema = z.enum([
  'enquiry',
  'site_visit',
  'rental_application',
  'rental_proposal',
  'tenancy',
  'maintenance',
  'garbage_service',
  'moving_job',
  'marketplace_request',
  'garbage_job',
  'laundry_order',
  'scheduling_activity',
  'general',
]);

export const startConversationSchema = z
  .object({
    type: conversationTypeSchema.optional(),
    subject: z.string().trim().max(255).optional(),
    propertyId: z.string().uuid().optional(),
    unitId: z.string().uuid().optional(),
    enquiryId: z.string().uuid().optional(),
    rentalApplicationId: z.string().uuid().optional(),
    rentalProposalId: z.string().uuid().optional(),
    siteVisitId: z.string().uuid().optional(),
    tenancyId: z.string().uuid().optional(),
    movingJobId: z.string().uuid().optional(),
    marketplaceRequestId: z.string().uuid().optional(),
    garbageJobId: z.string().uuid().optional(),
    laundryOrderId: z.string().uuid().optional(),
    schedulingActivityId: z.string().uuid().optional(),
    participantUserIds: z.array(z.string().uuid()).max(50).optional(),
    message: z.string().trim().max(5000).optional(),
  })
  .refine(
    (data) =>
      Boolean(
        data.enquiryId ||
          data.rentalApplicationId ||
          data.rentalProposalId ||
          data.siteVisitId ||
          data.tenancyId ||
          data.movingJobId ||
          data.marketplaceRequestId ||
          data.garbageJobId ||
          data.laundryOrderId ||
          data.schedulingActivityId ||
          data.propertyId,
      ),
    {
      message:
        'A context (enquiryId, rentalApplicationId, rentalProposalId, siteVisitId, tenancyId, movingJobId, marketplaceRequestId, garbageJobId, laundryOrderId, schedulingActivityId or propertyId) is required',
    },
  );

export const conversationIdParamSchema = z.object({
  conversationId: z.string().uuid(),
});

export const messageIdParamSchema = z.object({
  messageId: z.string().uuid(),
});

export const attachmentIdParamSchema = z.object({
  attachmentId: z.string().uuid(),
});

export const listConversationsQuerySchema = z.object({
  status: z.enum(['active', 'archived', 'all']).optional(),
  type: conversationTypeSchema.optional(),
  propertyId: z.string().uuid().optional(),
  search: z.string().trim().max(120).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional(),
});

export const listMessagesQuerySchema = z.object({
  before: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
});

export const sendMessageSchema = z.object({
  content: z.string().trim().min(1).max(5000),
  type: z.enum(['text', 'system']).optional(),
  replyToId: z.string().uuid().optional(),
});

export const markMessageReadSchema = z.object({
  messageId: z.string().uuid(),
});

export type StartConversationBody = z.infer<typeof startConversationSchema>;
export type ListConversationsQuery = z.infer<typeof listConversationsQuerySchema>;
export type ListMessagesQuery = z.infer<typeof listMessagesQuerySchema>;
export type SendMessageBody = z.infer<typeof sendMessageSchema>;