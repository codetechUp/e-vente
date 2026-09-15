-- Create notifications table
create table public.notifications (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  body text not null,
  type text not null, -- 'general', 'promo', 'restock'
  product_id bigint references public.products(id) on delete set null,
  image_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS (Row Level Security)
alter table public.notifications enable row level security;

-- Allow everyone (authenticated and anonymous) to read notifications
create policy "Allow public read access to notifications"
  on public.notifications for select
  using (true);

-- Allow authenticated users (like admin) to insert notifications
create policy "Allow authenticated insert access to notifications"
  on public.notifications for insert
  with check (auth.role() = 'authenticated');
