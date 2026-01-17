-- POLICY: Phase 8 - Super Admin Access

-- 1. Create Policy for Super Admins to view ALL schools
-- Note: We use a subquery to check the role of the current user from the profiles table.
-- WARNING: This assumes RLS is enabled on public.schools

create policy "Super Admins can view all schools"
on public.schools
for select
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and profiles.role = 'super_admin'
  )
);

-- 2. Create Policy for Super Admins to view ALL profiles (to count total users)
create policy "Super Admins can view all profiles"
on public.profiles
for select
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and profiles.role = 'super_admin'
  )
);

-- 3. Create Policy for Super Admins to view ALL subscriptions
create policy "Super Admins can view all subscriptions"
on public.subscriptions
for select
using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and profiles.role = 'super_admin'
  )
);
