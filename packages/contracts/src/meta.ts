export const metaFeaturePermissions = {
  insights: ['read_insights', 'instagram_manage_insights'],
  publishing: ['pages_manage_posts', 'instagram_content_publish'],
  ads: ['ads_read', 'ads_management'],
  messaging: ['pages_messaging', 'instagram_manage_messages', 'pages_manage_metadata'],
} as const;
export type MetaFeature = keyof typeof metaFeaturePermissions;
export const metaBasePermissions = ['pages_show_list', 'pages_read_engagement', 'instagram_basic'] as const;
export function metaPermissions(features: MetaFeature[]) {
  return [...new Set([...metaBasePermissions, ...features.flatMap(f => metaFeaturePermissions[f])])];
}
export function metaAccess(scopes: string[], instagramId: string | null, tasks: string[] = []) {
  const has = (...required: string[]) => required.every(p => scopes.includes(p));
  const task = (name: string) => tasks.includes(name) || tasks.includes('MANAGE');
  return {
    facebookInsights: has('read_insights', 'pages_read_engagement') && task('ANALYZE'),
    instagramInsights: Boolean(instagramId) && has('instagram_basic', 'instagram_manage_insights'),
    facebookPublishing: has('pages_manage_posts', 'pages_read_engagement') && task('CREATE_CONTENT'),
    instagramPublishing: Boolean(instagramId) && has('instagram_basic', 'instagram_content_publish'),
    adsRead: has('ads_read') || has('ads_management'),
    adsManage: has('ads_management'),
    facebookMessaging: has('pages_messaging') && task('MESSAGING'),
    instagramMessaging: Boolean(instagramId) && has('instagram_basic', 'instagram_manage_messages') && task('MESSAGING'),
    webhooks: has('pages_manage_metadata') && task('MANAGE'),
  };
}
