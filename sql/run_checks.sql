\set ON_ERROR_STOP on
\pset pager off
\echo Running the isolated PostgreSQL CRM integrity checks
BEGIN;
SET LOCAL search_path = pg_catalog;
SET LOCAL statement_timeout = '15s';
SET LOCAL lock_timeout = '5s';
\ir schema.sql
\ir fixtures.sql
\ir tests.sql
\ir reports.sql
ROLLBACK;
\echo PASS - all checks completed and the entire demo transaction was rolled back
