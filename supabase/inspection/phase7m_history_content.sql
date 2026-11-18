select version, name, statements
from supabase_migrations.schema_migrations
where version in ('20261110172940','20261110173339','20261110173506')
order by version;
