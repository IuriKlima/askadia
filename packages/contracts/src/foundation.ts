import { z } from 'zod';
import type { CompanyRecord } from './identity';

export const permissionActions = ['crm.read','crm.write','content.approve','strategy.approve','site.approve','ads.approve'] as const;
export const delegationSchema = z.object({
  userId:z.uuid(),action:z.enum(permissionActions),enabled:z.boolean(),
  budgetLimitCents:z.number().int().min(0).max(Number.MAX_SAFE_INTEGER).nullable().default(null),
  expiresAt:z.iso.datetime().nullable().default(null),
}).strict().refine(v=>!v.enabled||v.action!=='ads.approve'||v.budgetLimitCents!==null,'Defina o limite de orçamento.');
export const portfolioQuerySchema=z.object({search:z.string().trim().max(100).default(''),offset:z.coerce.number().int().min(0).max(100000).default(0)}).strict();
export const internalAccessSchema=z.object({companyId:z.uuid(),reason:z.string().trim().min(8).max(500)}).strict();
export const assignmentSchema=z.object({staffId:z.uuid(),assigned:z.boolean()}).strict();
export type StaffRole='platform_admin'|'support';
export type PlanRecord={id:'basic'|'premium'|'weekly';name:string;kind:'plan'|'addon';price_cents:number|null;currency:'BRL';checkout_enabled:boolean;features:string[];quotas:Record<string,number|null>};
export type CompanyCapabilities={companyId:string;actions:string[];subscription:{planId:string|null;status:string;weeklySupport:boolean;periodEnd:string|null};features:string[];quotas:Record<string,number|null>;billingEnabled:boolean};
export type PortfolioCompany=Pick<CompanyRecord,'id'|'name'|'city'|'segment'|'workspace_id'|'archived_at'|'created_at'>&{workspace_name:string;subscription_status:string;plan_id:string|null;weekly_support:boolean};
export type Portfolio={role:StaffRole;companies:PortfolioCompany[];total:number;offset:number;pageSize:number};
export type InternalContext={session:{id:string;company_id:string;operator_id:string;reason:string;started_at:string;expires_at:string;ended_at:string|null};company:CompanyRecord;subscription:{status:string;planId?:string;weeklySupport?:boolean;periodEnd?:string};team:{display_name:string;role:string}[];history:{action:string;actor_id:string;created_at:string}[];operatorRole:StaffRole;scope:'read_only'};
export type DelegationRecord={company_id:string;user_id:string;action:typeof permissionActions[number];budget_limit_cents:number|null;expires_at:string|null};
