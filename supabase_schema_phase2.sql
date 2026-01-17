-- Phase 2: Core Data & User Management

-- 1. Create 'schools' table
create table public.schools (
  id uuid default gen_random_uuid() primary key,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  name text not null,
  slug text, -- can be used for checking uniqueness or subdomain
  logo_url text,
  subscription_status text default 'active'
);

-- 2. Enable RLS on schools
alter table public.schools enable row level security;

-- 3. Update 'profiles' table to link to schools
-- We assume 'profiles' table already exists from Phase 1.
alter table public.profiles 
  add column school_id uuid references public.schools(id);

-- 4. RLS Policies for Schools
-- Policy: Users can view their own school
create policy "Users can view own school"
  on public.schools for select
  using (
    id in (
      select school_id from public.profiles 
      where profiles.id = auth.uid()
    )
  );

-- Policy: Users can update their own school
create policy "School Admins can update own school"
  on public.schools for update
  using (
    id in (
      select school_id from public.profiles 
      where profiles.id = auth.uid()
    )
  );

-- Policy: Allow insertion during onboarding (we might need a more permissive policy or handle via function)
-- For a simple start: Authenticated users can create a school. 
-- *Strictly speaking, we might want to restrict this, but for this SaaS MVP, anyone signed up can create a school.*
create policy "Authenticated users can insert school"
  on public.schools for insert
  with check ( auth.role() = 'authenticated' );

-- 5. Update Policies for Profiles (Multi-tenancy enforcement)
-- Users should technically only see profiles from their own school (Phase 2 goal: Isolated Data)
-- We need to update the Phase 1 policy "Users can view own profile".
-- Creating a new policy for viewing PEERS in the same school.

create policy "Users can view profiles from same school"
  on public.profiles for select
  using (
    school_id in (
      select school_id from public.profiles
      where id = auth.uid()
    )
  );
