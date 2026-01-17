-- Fix: Create missing subscriptions table and add Razorpay columns
-- This consolidates logic from Phase 5 and Phase 8 (Razorpay)

-- 1. Create Subscriptions Table (From Phase 5)
create table if not exists public.subscriptions (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  stripe_subscription_id text, -- ID from Stripe
  stripe_customer_id text,
  plan_id text not null, -- 'basic' or 'pro'
  status text not null, -- 'active', 'past_due', 'canceled', 'incomplete'
  current_period_end timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (if not already enabled)
alter table public.subscriptions enable row level security;

-- Policy: View own school subscription (From Phase 5)
-- (Dropping first to avoid conflicts if it exists but table didn't ?)
-- Actually, if table didn't exist, policy wouldn't either.
-- But using DO block for safety if we want to be idempotent, 
-- or just CREATE POLICY IF NOT EXISTS (Postgres 16+? No, simpler to just Create and let it fail if exists or drop first)

drop policy if exists "View own school subscription" on public.subscriptions;
create policy "View own school subscription" on public.subscriptions
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- 2. Add Razorpay columns (From Phase 8 Razorpay)
ALTER TABLE public.subscriptions 
ADD COLUMN IF NOT EXISTS razorpay_order_id text,
ADD COLUMN IF NOT EXISTS razorpay_payment_id text,
ADD COLUMN IF NOT EXISTS razorpay_signature text;

-- 3. Make stripe columns nullable (From Phase 8 Razorpay)
ALTER TABLE public.subscriptions ALTER COLUMN stripe_subscription_id DROP NOT NULL;
ALTER TABLE public.subscriptions ALTER COLUMN stripe_customer_id DROP NOT NULL;
