-- Phase 3: Academic Management

-- 1. Batches Table
create table public.batches (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  name text not null,
  start_date date,
  end_date date,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Students Table
create table public.students (
  id uuid default gen_random_uuid() primary key,
  school_id uuid references public.schools(id) not null,
  full_name text not null,
  email text,
  roll_number text,
  status text default 'active' check (status in ('active', 'inactive')),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. Student-Batch Enrollment (Junction Table)
create table public.student_batches (
  id uuid default gen_random_uuid() primary key,
  student_id uuid references public.students(id) on delete cascade not null,
  batch_id uuid references public.batches(id) on delete cascade not null,
  school_id uuid references public.schools(id) not null, -- Denormalized for easier RLS
  enrolled_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, batch_id)
);

-- 4. Attendance Table
create table public.attendance (
  id uuid default gen_random_uuid() primary key,
  student_id uuid references public.students(id) not null,
  batch_id uuid references public.batches(id) not null,
  school_id uuid references public.schools(id) not null,
  date date not null default CURRENT_DATE,
  status text check (status in ('present', 'absent', 'excused')) not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(student_id, batch_id, date)
);

-- Enable RLS
alter table public.batches enable row level security;
alter table public.students enable row level security;
alter table public.student_batches enable row level security;
alter table public.attendance enable row level security;

-- Policies

-- Batches: Users can view/edit batches of their own school
create policy "View batches of own school" on public.batches
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage batches of own school" on public.batches
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Students: Users can view/edit students of their own school
create policy "View students of own school" on public.students
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage students of own school" on public.students
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Student Batches
create policy "View enrollments of own school" on public.student_batches
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage enrollments of own school" on public.student_batches
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

-- Attendance
create policy "View attendance of own school" on public.attendance
  for select using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );

create policy "Manage attendance of own school" on public.attendance
  for all using (
    school_id in (select school_id from public.profiles where id = auth.uid())
  );
