-- ════════════════════════════════════════════════════════════
-- FinansAsistan - PostgreSQL Bootstrap Script
-- Bu script Docker container ilk başlatıldığında çalışır
-- Location: /docker-entrypoint-initdb.d/01_init.sql
-- ════════════════════════════════════════════════════════════

\echo '════════════════════════════════════════════════════════'
\echo 'FinansAsistan PostgreSQL Bootstrap Started'
\echo '════════════════════════════════════════════════════════'

-- Database zaten oluşturulmuş (POSTGRES_DB env var)
-- Sadece extensions ve initial setup

-- ════════════════════════════════════════════════════════════
-- Extensions
-- ════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Text search optimization

\echo '✅ Extensions created'

-- ════════════════════════════════════════════════════════════
-- Performance Configuration
-- ════════════════════════════════════════════════════════════

-- Shared preload libraries
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- Memory settings (will be adjusted by bootstrap/postgresql.conf)
-- ALTER SYSTEM SET shared_buffers = '2GB';
-- ALTER SYSTEM SET effective_cache_size = '6GB';

\echo '✅ Performance settings configured'

-- ════════════════════════════════════════════════════════════
-- Create Schema from migration script
-- ════════════════════════════════════════════════════════════

\i /docker-entrypoint-initdb.d/001_initial_schema.sql

\echo '✅ Database schema created'

-- ════════════════════════════════════════════════════════════
-- Verify Installation
-- ════════════════════════════════════════════════════════════

\echo ''
\echo '════════════════════════════════════════════════════════'
\echo 'Database Tables:'
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

\echo ''
\echo 'Database Size:'
SELECT pg_size_pretty(pg_database_size(current_database()));

\echo ''
\echo '════════════════════════════════════════════════════════'
\echo '✅ FinansAsistan PostgreSQL Bootstrap Complete!'
\echo 'Database is ready for connections'
\echo '════════════════════════════════════════════════════════'

