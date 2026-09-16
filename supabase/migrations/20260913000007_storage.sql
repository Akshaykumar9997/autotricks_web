-- AutoTricks hardening 5/5: private Storage buckets and policies.
-- Object layout: {client_id}/...   (first folder is always the owning client)
--   signatures/{client_id}/{revision_id}/{file}.png   drawn signature (client upload, write-once)
--   quotation-pdfs/{client_id}/...                    admin generated
--   signed-quotation-pdfs/{client_id}/...             admin generated, write-once
--   service-documents/{client_id}/...                 reports, invoices, receipts

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('signatures', 'signatures', false, 524288, array['image/png']),
  ('quotation-pdfs', 'quotation-pdfs', false, 10485760, array['application/pdf']),
  ('signed-quotation-pdfs', 'signed-quotation-pdfs', false, 10485760, array['application/pdf']),
  ('service-documents', 'service-documents', false, 20971520,
   array['application/pdf', 'image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- A client may upload a signature only into their own folder, for their own
-- ACCEPTED, not-yet-signed revision that they accepted themselves.
create or replace function private.can_upload_signature(p_object_name text)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_parts text[] := string_to_array(p_object_name, '/');
  v_client uuid := private.current_client_id();
  v_revision_id uuid;
begin
  if v_client is null
     or coalesce(array_length(v_parts, 1), 0) <> 3
     or v_parts[1] <> v_client::text
     or v_parts[3] !~ '^[A-Za-z0-9_-]{1,64}\.png$' then
    return false;
  end if;

  begin
    v_revision_id := v_parts[2]::uuid;
  exception when others then
    return false;
  end;

  return exists (
    select 1 from public.quotation_revisions qr
    where qr.id = v_revision_id
      and qr.status = 'ACCEPTED'
      and qr.accepted_by_profile_id = (select auth.uid())
      and private.revision_client_id(qr.id) = v_client
      and not exists (select 1 from public.quotation_signatures qs where qs.quotation_revision_id = qr.id)
  );
end;
$$;

create or replace function private.is_client_folder(p_object_name text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.clients c
    where c.id::text = split_part(p_object_name, '/', 1)
  );
$$;

create or replace function private.is_registered_document(p_bucket text, p_object_name text)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.documents d
    where d.storage_bucket = p_bucket and d.storage_path = p_object_name
  );
$$;

revoke all on function
  private.can_upload_signature(text),
  private.is_client_folder(text),
  private.is_registered_document(text, text)
from public;

grant execute on function
  private.can_upload_signature(text),
  private.is_client_folder(text),
  private.is_registered_document(text, text)
to authenticated, service_role;

-- Read
create policy autotricks_admin_read_objects
on storage.objects for select to authenticated
using (
  bucket_id in ('signatures', 'quotation-pdfs', 'signed-quotation-pdfs', 'service-documents')
  and (select private.is_admin())
);

create policy autotricks_client_read_own_objects
on storage.objects for select to authenticated
using (
  bucket_id in ('signatures', 'quotation-pdfs', 'signed-quotation-pdfs', 'service-documents')
  and (storage.foldername(name))[1] = (select private.current_client_id())::text
);

-- Write: client signature upload (no update/delete policy exists => write-once)
create policy autotricks_client_upload_signature
on storage.objects for insert to authenticated
with check (
  bucket_id = 'signatures'
  and private.can_upload_signature(name)
);

-- Write: admin document uploads into an existing client's folder
create policy autotricks_admin_upload_documents
on storage.objects for insert to authenticated
with check (
  bucket_id in ('quotation-pdfs', 'signed-quotation-pdfs', 'service-documents')
  and (select private.is_admin())
  and private.is_client_folder(name)
);

-- Admin may replace/remove unregistered files in the non-signed buckets only.
-- Signatures and signed quotation PDFs have no update/delete policy at all.
create policy autotricks_admin_update_unregistered_documents
on storage.objects for update to authenticated
using (
  bucket_id in ('quotation-pdfs', 'service-documents')
  and (select private.is_admin())
  and not private.is_registered_document(bucket_id, name)
)
with check (
  bucket_id in ('quotation-pdfs', 'service-documents')
  and (select private.is_admin())
  and private.is_client_folder(name)
  and not private.is_registered_document(bucket_id, name)
);

create policy autotricks_admin_delete_unregistered_documents
on storage.objects for delete to authenticated
using (
  bucket_id in ('quotation-pdfs', 'service-documents')
  and (select private.is_admin())
  and not private.is_registered_document(bucket_id, name)
);
