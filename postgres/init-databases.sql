\set ON_ERROR_STOP on

-- Run with psql as the application database owner, connected to a maintenance database.
-- CREATE DATABASE must run outside a transaction.
SELECT format('CREATE DATABASE %I', required.name)
FROM (VALUES ('user_db'), ('plaza_db'), ('traceability_db')) AS required(name)
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = required.name
)
\gexec
