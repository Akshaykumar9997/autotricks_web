-- AutoTricks Phase 3: Device Tokens & Push Notification Dispatch

-- 1. Create pg_net extension if not present
create extension if not exists pg_net with schema extensions;

-- 2. Create device_tokens table
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null,
  platform text not null check (platform in ('android', 'ios', 'web', 'windows', 'macos')),
  device_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint device_tokens_fcm_token_key unique (fcm_token)
);

-- 3. Indexes
create index if not exists idx_device_tokens_profile_active 
  on public.device_tokens(profile_id) 
  where is_active = true;

create index if not exists idx_device_tokens_fcm_token 
  on public.device_tokens(fcm_token);

-- 4. Updated_at trigger
drop trigger if exists device_tokens_updated_at on public.device_tokens;
create trigger device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

-- 5. Grants
grant select, insert, update on public.device_tokens to authenticated;
grant all on public.device_tokens to service_role;

-- 6. Row Level Security (RLS)
alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own
  on public.device_tokens for select to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists device_tokens_insert_own on public.device_tokens;
create policy device_tokens_insert_own
  on public.device_tokens for insert to authenticated
  with check (profile_id = (select auth.uid()));

drop policy if exists device_tokens_update_own on public.device_tokens;
create policy device_tokens_update_own
  on public.device_tokens for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- 7. Push Notification Dispatch Trigger
create or replace function private.dispatch_push_notification()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_url text;
begin
  v_url := 'https://extsmeyxnzhhvcmwyvbi.supabase.co/functions/v1/push-notification-dispatcher';

  begin
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'notification_id', new.id,
        'profile_id', new.profile_id,
        'type', new.type,
        'title', new.title,
        'message', new.message,
        'entity_type', new.entity_type,
        'entity_id', new.entity_id,
        'created_at', new.created_at
      )
    );
  exception when others then
    raise warning 'Push notification dispatch enqueue failed: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists notifications_push_dispatch on public.notifications;
create trigger notifications_push_dispatch
  after insert on public.notifications
  for each row execute function private.dispatch_push_notification();

-- 8. Device Token Registration & Deactivation Helper RPCs
create or replace function public.register_device_token(
  p_fcm_token text,
  p_platform text,
  p_device_name text default null
)
returns public.device_tokens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_record public.device_tokens;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to register device token';
  end if;

  insert into public.device_tokens (
    profile_id,
    fcm_token,
    platform,
    device_name,
    is_active,
    last_seen_at,
    updated_at
  )
  values (
    v_user_id,
    p_fcm_token,
    p_platform,
    p_device_name,
    true,
    now(),
    now()
  )
  on conflict (fcm_token) do update
  set
    profile_id = v_user_id,
    platform = excluded.platform,
    device_name = coalesce(excluded.device_name, device_tokens.device_name),
    is_active = true,
    last_seen_at = now(),
    updated_at = now()
  returning * into v_record;

  return v_record;
end;
$$;

create or replace function public.deactivate_device_token(
  p_fcm_token text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return false;
  end if;

  update public.device_tokens
  set
    is_active = false,
    updated_at = now()
  where fcm_token = p_fcm_token
    and profile_id = v_user_id;

  return found;
end;
$$;

grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.deactivate_device_token(text) to authenticated;

