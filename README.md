# PostgreSQL data quality demo

A small SQL project for practicing database testing with a fictional business CRM.

This is a new educational demonstration prepared with AI assistance for Karina to review, run, and explain. It is not previous client work or a production system. Every company, contact, and opportunity is invented.

## What this project demonstrates

- Designing related PostgreSQL tables
- Enforcing required values, uniqueness, foreign keys, and business rules
- Checking both valid data and rejected changes
- Understanding SQLSTATE error codes and named constraints
- Keeping test changes inside a transaction that is always rolled back
- Writing simple CRM reports without mixing currencies

## Current verification status

The SQL has not been executed on PostgreSQL in the preparation environment. PostgreSQL and Docker were unavailable there. The shell script passed a shell syntax check, and the repository passed its standard-library static checks.

The suite defines 45 checks. This is the number of authored checks, not a claim that they have passed on a database. Run the commands below to establish the database result yourself. More details are in [VALIDATION.md](VALIDATION.md).

## Data model

One account can have several contacts and opportunities. Each opportunity references both a contact and its account. A composite foreign key prevents an opportunity from using a contact from another company.

- accounts stores the company name, billing email, and creation date
- contacts stores a person and their company
- opportunities stores a sales opportunity, amount, currency, stage, and dates

The fixture contains three accounts, four contacts, and five opportunities. Amounts use USD or EUR. Fixed IDs and dates keep the demonstration repeatable.

## Run with Docker

You need Docker with the Compose plugin. The first run downloads the official PostgreSQL 17 image and needs internet access. The image tag follows maintenance updates within PostgreSQL 17.

From this repository run the following command.

```sh
./scripts/run_checks.sh
```

The script starts a disposable database, waits for readiness, runs the SQL suite, and removes the container on exit. The database is held in temporary memory. It has no published port, no TCP listener, and no container network. Trust authentication is used only inside this isolated demo container. Do not copy that setting into a shared or production database.

The final successful output should include the following line.

```text
PASS - all checks completed and the entire demo transaction was rolled back
```

A failed check stops psql and returns a nonzero exit code. Read the first error above the container cleanup output.

Only one run should use this Compose project at a time. The cleanup command stops containers belonging to the karina-postgres-quality project.

## Run against an existing local PostgreSQL database

Use an empty, disposable database owned by you. Do not run this project against a production database. The role must be able to create schemas and functions.

```sh
psql -X -d postgres_quality_demo -v ON_ERROR_STOP=1 -f sql/run_checks.sql
```

Authentication is configured separately through your normal local PostgreSQL setup. The repository contains no credentials. The target is PostgreSQL 17. Other PostgreSQL versions have not been validated.

The runner creates crm_demo and then rolls back the whole transaction. If that schema already exists, the run fails instead of deleting or changing it. Do not run schema.sql and fixtures.sql separately unless you intend to create persistent objects in a disposable database.

## Inspect the files

- [sql/schema.sql](sql/schema.sql) defines tables, constraints, and indexes
- [sql/fixtures.sql](sql/fixtures.sql) loads invented business data
- [sql/tests.sql](sql/tests.sql) contains the assertions and negative cases
- [sql/reports.sql](sql/reports.sql) produces grouped totals and data quality counts
- [sql/run_checks.sql](sql/run_checks.sql) wraps everything in one transaction
- [docs/test-plan.md](docs/test-plan.md) describes coverage and expected results
- [docs/explanation-guide.md](docs/explanation-guide.md) helps with review and practice

## Static checks without PostgreSQL

These checks inspect file structure and test metadata. They do not parse or execute SQL.

```sh
python3 scripts/check_repository.py
sh -n scripts/run_checks.sh
```

## Scope and limitations

The email check is deliberately basic. It is not a full email standard validator or proof that an address exists. Emails must be lower case with no surrounding spaces. Billing emails are unique across accounts. Contact emails are unique within each account.

Amounts must be greater than zero, at most 999999999.99, and have no fractional cents. The schema uses unconstrained numeric with an explicit precision rule so PostgreSQL does not silently round input before validation. Zero, negatives, NaN, and infinities are rejected.

A won or lost opportunity needs a closing date. An open opportunity has none. A closing date cannot precede its opening date. This is a row-level consistency rule, not a full history-based workflow. Reopening a deal is allowed if its closing date is cleared.

Won opportunity values are not accounting revenue. There are no invoices, tax rules, exchange rates, authentication, permissions model, migrations, backup exercises, or performance claims. This is a SQL integrity and testing example, not evidence of operating a production database.

## Reference material

- [PostgreSQL 17 constraints](https://www.postgresql.org/docs/17/ddl-constraints.html)
- [PostgreSQL 17 exception handling](https://www.postgresql.org/docs/17/plpgsql-control-structures.html#PLPGSQL-ERROR-TRAPPING)
- [PostgreSQL 17 numeric types](https://www.postgresql.org/docs/17/datatype-numeric.html)
- [Official PostgreSQL container image](https://hub.docker.com/_/postgres)
