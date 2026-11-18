-- Included by the executor INSIDE each package transaction; no separate commit.
-- This records package execution without falsely recording historical migrations.
create table if not exists private.sai_deployment_packages (
  package_id text primary key,
  source_path text not null,
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  manifest_sha256 text not null check (manifest_sha256 ~ '^[0-9a-f]{64}$'),
  git_commit text not null check (git_commit ~ '^[0-9a-f]{40}$'),
  verified_at timestamptz not null default clock_timestamp()
);
alter table private.sai_deployment_packages enable row level security;
revoke all on private.sai_deployment_packages from public, anon, authenticated, service_role;
