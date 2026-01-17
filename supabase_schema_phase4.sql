-- Phase 4: Communication & Media

-- 1. Announcements Table
create table public.announcements (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  target_batch_id uuid references public.batches(id), -- Nullable means "All Batches"
  title text not null,
  message text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Assignments Table
create table public.assignments (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  batch_id uuid references public.batches(id) not null,
  title text not null,
  description text,
  file_url text, -- URL returned from FastAPI/Supabase Storage
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.announcements enable row level security;
alter table public.assignments enable row level security;

-- Policies

-- Announcements: Users can view announcements of their own school
create policy "View announcements of own school" on public.announcements
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage announcements of own school" on public.announcements
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Assignments: Users can view assignments of their own school
create policy "View assignments of own school" on public.assignments
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage assignments of own school" on public.assignments
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Storage Buckets (If not already created via UI)
-- Note: Creating buckets via SQL is not standard in Supabase SQL editor usually, 
-- but we can insert into storage.buckets if permissions allow.
-- Better to instruct user or use UI.
-- insert into storage.buckets (id, name) values ('media', 'media'); 

-- Storage Policies (If 'media' bucket exists)
-- create policy "Media Public Access" on storage.objects for select using ( bucket_id = 'media' );
-- create policy "Media Upload Access" on storage.objects for insert with check ( bucket_id = 'media' );
