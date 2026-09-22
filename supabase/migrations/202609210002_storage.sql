-- Private assets. Size/type are provisional technical safeguards, not commercial quotas.
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('company-assets','company-assets',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false;
create policy company_assets_read on storage.objects for select to authenticated
  using(bucket_id='company-assets' and private.file_access(name,array['admin','approver','support']));
create policy company_assets_insert on storage.objects for insert to authenticated
  with check(bucket_id='company-assets' and private.file_access(name,array['admin']));
create policy company_assets_update on storage.objects for update to authenticated
  using(bucket_id='company-assets' and private.file_access(name,array['admin']))
  with check(bucket_id='company-assets' and private.file_access(name,array['admin']));
create policy company_assets_delete on storage.objects for delete to authenticated
  using(bucket_id='company-assets' and private.file_access(name,array['admin']));
commit;
