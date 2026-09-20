-- SmartLedger cloud schema.
-- Run once in the Supabase SQL editor for your project (Project → SQL Editor).
--
-- Design note: posted transactions and their lines are never edited or
-- deleted locally (see LedgerRepository.reverse in the Flutter app), so
-- syncing them is a plain append-only upsert-by-id — no conflict logic
-- needed. Only `accounts` can be edited in place, so it alone carries
-- `updated_at` for last-write-wins merging.

create table if not exists public.accounts (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  code text not null,
  name_am text not null,
  name_en text not null,
  type text not null,
  opening_balance bigint not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  date timestamptz not null,
  reference text default '',
  memo text default '',
  attachment_path text,
  created_at timestamptz not null,
  reversal_of_id text references public.transactions (id)
);

create table if not exists public.journal_lines (
  id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  transaction_id text not null references public.transactions (id) on delete cascade,
  account_id text not null,
  debit bigint not null default 0,
  credit bigint not null default 0,
  note text default ''
);

create index if not exists idx_accounts_user on public.accounts (user_id);
create index if not exists idx_tx_user on public.transactions (user_id);
create index if not exists idx_tx_user_date on public.transactions (user_id, date);
create index if not exists idx_lines_user on public.journal_lines (user_id);
create index if not exists idx_lines_transaction on public.journal_lines (transaction_id);

alter table public.accounts enable row level security;
alter table public.transactions enable row level security;
alter table public.journal_lines enable row level security;

-- Every row is only ever visible to, and writable by, the user who owns it.
create policy "accounts_owner" on public.accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "transactions_owner" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "journal_lines_owner" on public.journal_lines
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
