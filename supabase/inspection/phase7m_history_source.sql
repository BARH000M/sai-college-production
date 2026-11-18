select version, name, cardinality(statements) statement_count,
  encode(sha256(convert_to(btrim(regexp_replace(btrim(replace(array_to_string(statements,E'\n'),chr(13),'')), ';+$','','g')), 'UTF8')), 'hex') as normalized_source_sha256
from supabase_migrations.schema_migrations
where version in ('20261110172940','20261110173339','20261110173506')
order by version;
