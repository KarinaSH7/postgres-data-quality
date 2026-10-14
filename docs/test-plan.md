# Test plan

## Purpose

Check that a small CRM database accepts valid rows and rejects changes that would break its business rules. All examples use invented data.

## Preconditions

- PostgreSQL 17 is running in a disposable database
- The connected role can create a schema and PL/pgSQL functions
- The crm_demo schema does not already exist
- psql runs with ON_ERROR_STOP enabled

## Execution

Run scripts/run_checks.sh through Docker or use the local psql command in the README. The runner includes the schema, fixtures, tests, and reports in one transaction.

An expected rejection passes only when its SQLSTATE matches. Cases for named constraints also require the exact constraint name. An unexpected SQL error must fail the test.

Each rejection is handled in a nested PL/pgSQL exception block. PostgreSQL rolls back the work in that block. A final ROLLBACK removes the demo tables, temporary test helpers, and all inserted data. If psql stops on an error, closing its connection rolls back the still-open transaction.

## Positive cases

- P01 through P03 check fixture row counts
- P04 checks the USD won value of 1800
- P05 checks the open USD pipeline of 300
- P06 checks the open EUR pipeline of 850
- P07 through P09 check that failed changes left the original data intact
- P10 allows a shared contact email across different accounts
- P11 accepts the minimum amount of 0.01
- P12 accepts the maximum amount of 999999999.99
- P13 accepts a same-day close with a consistent stage and closing date
- P14 proves the rejection helper fails if SQL is unexpectedly accepted
- P15 proves the rejection helper fails for the wrong SQLSTATE

## Negative cases

- N01 and N02 reject duplicate account IDs and billing emails
- N03 and N04 reject blank or missing company names
- N05 and N06 reject non-normalized or malformed billing emails
- N07 rejects a contact with a missing account
- N08 rejects duplicate contact emails in the same account
- N09 and N10 reject blank contact names and malformed emails
- N11 rejects a missing contact account
- N12 rejects a missing opportunity contact
- N13 rejects a contact from a different account
- N14 rejects a missing opportunity contact value
- N15 through N22 reject zero, negative, fractional-cent, oversized, NaN, infinite, and null amounts
- N23 rejects unsupported currencies
- N24 rejects unsupported stages
- N25 and N26 reject an inconsistent stage and closing date
- N27 rejects a closing date before opening
- N28 prevents deleting a contact referenced by an opportunity
- N29 prevents moving a referenced contact to another account
- N30 rejects a blank opportunity title

## Expected report values

For currency and stage totals the unchanged fixtures produce these rows.

```text
EUR  lost       1   450.00
EUR  new        1   850.00
USD  qualified  1   300.00
USD  won        2  1800.00
```

The account report shows Cedar Workshop with USD 300 open and USD 1200 won, Harbor Studio with EUR 850 open and EUR 0 won, and Meadow Books with USD 0 open and USD 600 won.

All four data quality counters must be zero. The suite asserts fixture counts and key business totals. The report statements themselves are display queries, not a complete independently asserted reporting test suite.

## Pass criteria

All 45 assertions appear in test_results, passed_checks is 45, and the runner reaches its final PASS message after ROLLBACK. No database pass is claimed until this has actually run on PostgreSQL.

## Deliberate gaps

This suite does not test concurrent sessions, role permissions, backups, query performance, migrations, or application API behavior. The basic email policy is narrower than the full email standard. No external customer data is required.

A useful next exercise is to add a test for an account that has contacts but no opportunities, then explain why its deletion is blocked. Another is to remove one constraint in a disposable copy and prove that the matching test fails.
