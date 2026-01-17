-- 1. Create a table for public profiles (links to auth.users)
create table public.profiles (
  id uuid references auth.users on delete cascade,
  email text,
  full_name text,
  role text default 'school_admin', -- Options: 'super_admin', 'school_admin'
  school_id uuid, -- Will be linked in Phase 2
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (id)
);

-- 2. Enable Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. Create Policy: Public profiles are viewable by everyone (or just authenticated users - adhering to "Data Isolation")
-- For now, allow users to read their own profile.
create policy "Users can view own profile" 
on public.profiles for select 
using ( auth.uid() = id );

-- 4. Create Policy: Users can update their own profile
create policy "Users can update own profile" 
on public.profiles for update 
using ( auth.uid() = id );

-- 5. Trigger to automatically create a profile entry when a new user signs up via Supabase Auth
create function public.handle_new_user() 
returns trigger 
language plpgsql 
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name', 'school_admin');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
