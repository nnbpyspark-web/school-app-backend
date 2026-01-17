-- Fix for Infinite Recursion in RLS Policies
-- The previous policies caused infinite recursion because they queried the 'profiles' table within the policy definition for 'profiles'.
-- We resolve this by using a SECURITY DEFINER function which bypasses RLS for the role check.

-- 1. Create a secure function to check for super_admin role
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'super_admin'
  );
$$;

-- 2. Drop the problematic recursive policies
DROP POLICY IF EXISTS "Super Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Super Admins can view all schools" ON public.schools;
DROP POLICY IF EXISTS "Super Admins can view all subscriptions" ON public.subscriptions;

-- 3. Recreate policies using the secure function
-- Policy for Profiles
CREATE POLICY "Super Admins can view all profiles"
ON public.profiles
FOR SELECT
USING ( is_super_admin() );

-- Policy for Schools
CREATE POLICY "Super Admins can view all schools"
ON public.schools
FOR SELECT
USING ( is_super_admin() );

-- Policy for Subscriptions
CREATE POLICY "Super Admins can view all subscriptions"
ON public.subscriptions
FOR SELECT
USING ( is_super_admin() );
