# Review and practice guide

This project was prepared with AI assistance. Read the SQL, run it, and change a few tests before presenting it as something you understand. Describe your own contribution accurately. Do not describe this demonstration as paid work, previous client work, or a production deployment.

## Explain the problem

A CRM must not lose the relationship between a company, its contacts, and its sales opportunities. It must also reject duplicate identifiers and invalid amounts. Application validation is useful, but database constraints protect all callers, including imports and direct SQL changes.

## Explain the relationships

A normal foreign key to contact_id only proves that the contact exists. The composite foreign key using contact_id and account_id also proves that the contact belongs to the opportunity's company.

The contacts table therefore has a unique constraint on that same pair. Explain why the extra unique constraint is needed for this reference even though contact_id is already a primary key.

## Explain the amount rule

NUMERIC stores exact decimal values. A type such as NUMERIC(12, 2) can round extra decimal places while accepting input. This project deliberately uses a numeric value with a CHECK constraint to reject fractional cents instead.

The amount is positive and bounded. PostgreSQL has special numeric NaN and infinity values. The upper bound keeps them out too. Tests cover these cases explicitly.

## Explain null handling

A CHECK constraint can accept an unknown result caused by NULL. That is why required fields also have NOT NULL. Read N22 and identify the difference between SQLSTATE 23502 and 23514.

## Explain failure isolation

The whole demonstration runs inside BEGIN and ROLLBACK. Expected failures happen in smaller exception blocks. PostgreSQL rolls back those blocks so the next test can still execute. The helper checks the expected SQLSTATE and, where available, the named constraint.

The final transaction rollback also removes the schema. This is not a reset command and does not drop a pre-existing schema. If crm_demo already exists, the run stops safely.

## Explain the reports

Amounts are grouped by currency. Adding EUR and USD into one total without exchange-rate rules would be misleading. A won opportunity is a CRM outcome, not a recognized accounting payment or revenue event.

## Questions to answer in your own words

1. What does a foreign key protect that a primary key cannot?
2. Why are both NOT NULL and CHECK used for an amount?
3. What would happen if N13 used only a contact_id foreign key?
4. How does the test helper avoid treating a syntax error as a passing rejection?
5. Why does deleting a referenced contact fail?
6. Why are the referencing columns explicitly indexed?
7. What changes would make this appropriate for a shared database?
8. Which guarantees are missing because there is no application or authentication layer?

## Small practice changes

- Add a company with no opportunities and extend the report with a LEFT JOIN
- Add a new allowed currency and an explicit test for it
- Test rejection of leading spaces in an email address
- Add a contacts-only account and test its deletion
- Run the suite twice to verify that the first rollback left no schema behind
- Change one expected SQLSTATE and confirm the suite returns a failure

## Honest project description

After you have reviewed and run the project, you can describe it as a learning demo you worked through with AI assistance. Mention the parts you can explain and the tests you personally added or changed. Keep the validation record accurate and avoid implying production database administration experience from this repository alone.
