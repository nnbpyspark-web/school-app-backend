-- Phase 5: SaaS Monetization

-- 1. Subscriptions Table
create table public.subscriptions (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  stripe_subscription_id text, -- ID from Stripe
  stripe_customer_id text,
  plan_id text not null, -- 'basic' or 'pro'
  status text not null, -- 'active', 'past_due', 'canceled', 'incomplete'
  current_period_end timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.subscriptions enable row level security;

-- Policies
create policy "View own school subscription" on public.subscriptions
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Only system/service_role should update this generally, but allow admins to read.
