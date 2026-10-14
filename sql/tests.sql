CREATE TEMPORARY TABLE test_results (
    test_name text PRIMARY KEY,
    passed boolean NOT NULL CHECK (passed)
) ON COMMIT DROP;

CREATE FUNCTION pg_temp.expect_true(test_name text, actual boolean)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF actual IS DISTINCT FROM true THEN
        RAISE EXCEPTION 'FAIL %', test_name;
    END IF;
    INSERT INTO pg_temp.test_results VALUES (test_name, true);
END;
$$;

-- A caught exception rolls back the statements inside its nested BEGIN block.
-- Check both SQLSTATE and constraint name. A different failure must not pass.
CREATE FUNCTION pg_temp.expect_rejected(
    test_name text, statement text, expected_state text, expected_constraint text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    actual_state text;
    actual_constraint text;
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            actual_state = RETURNED_SQLSTATE,
            actual_constraint = CONSTRAINT_NAME;
        IF actual_state <> expected_state
           OR (expected_constraint IS NOT NULL AND actual_constraint <> expected_constraint) THEN
            RAISE EXCEPTION 'FAIL % - expected % / %, received % / %',
                test_name, expected_state, expected_constraint, actual_state, actual_constraint;
        END IF;
        INSERT INTO pg_temp.test_results VALUES (test_name, true);
        RETURN;
    END;
    RAISE EXCEPTION 'FAIL % - statement was accepted', test_name;
END;
$$;

-- Baseline checks confirm that valid data loaded correctly.
SELECT pg_temp.expect_true('P01 account fixture count', (SELECT count(*) = 3 FROM crm_demo.accounts));
SELECT pg_temp.expect_true('P02 contact fixture count', (SELECT count(*) = 4 FROM crm_demo.contacts));
SELECT pg_temp.expect_true('P03 opportunity fixture count', (SELECT count(*) = 5 FROM crm_demo.opportunities));
SELECT pg_temp.expect_true('P04 USD won value', (
    SELECT sum(amount) = 1800 FROM crm_demo.opportunities WHERE currency = 'USD' AND stage = 'won'
));
SELECT pg_temp.expect_true('P05 open USD pipeline', (
    SELECT sum(amount) = 300 FROM crm_demo.opportunities WHERE currency = 'USD' AND stage IN ('new', 'qualified')
));
SELECT pg_temp.expect_true('P06 open EUR pipeline', (
    SELECT sum(amount) = 850 FROM crm_demo.opportunities WHERE currency = 'EUR' AND stage IN ('new', 'qualified')
));

-- Each rejected statement is independent and must leave the fixtures unchanged.
SELECT pg_temp.expect_rejected('N01 duplicate account ID',
    $$INSERT INTO crm_demo.accounts VALUES (1, 'New company', 'new@example.test', DATE '2026-01-01')$$,
    '23505', 'accounts_pkey');
SELECT pg_temp.expect_rejected('N02 duplicate billing email',
    $$INSERT INTO crm_demo.accounts VALUES (99, 'New company', 'billing@cedar.test', DATE '2026-01-01')$$,
    '23505', 'accounts_billing_email_unique');
SELECT pg_temp.expect_rejected('N03 blank company name',
    $$UPDATE crm_demo.accounts SET company_name = '   ' WHERE account_id = 1$$,
    '23514', 'accounts_company_name_not_blank');
SELECT pg_temp.expect_rejected('N04 null company name',
    $$UPDATE crm_demo.accounts SET company_name = NULL WHERE account_id = 1$$, '23502');
SELECT pg_temp.expect_rejected('N05 uppercase billing email',
    $$UPDATE crm_demo.accounts SET billing_email = 'Billing@cedar.test' WHERE account_id = 1$$,
    '23514', 'accounts_email_normalized');
SELECT pg_temp.expect_rejected('N06 invalid billing email',
    $$UPDATE crm_demo.accounts SET billing_email = 'not-an-email' WHERE account_id = 1$$,
    '23514', 'accounts_email_shape');
SELECT pg_temp.expect_rejected('N07 orphan contact',
    $$INSERT INTO crm_demo.contacts VALUES (99, 999, 'Demo Person', 'demo@example.test')$$,
    '23503', 'contacts_account_fk');
SELECT pg_temp.expect_rejected('N08 duplicate contact email within account',
    $$INSERT INTO crm_demo.contacts VALUES (99, 1, 'Demo Person', 'alex@cedar.test')$$,
    '23505', 'contacts_account_email_unique');
SELECT pg_temp.expect_rejected('N09 blank contact name',
    $$UPDATE crm_demo.contacts SET full_name = '' WHERE contact_id = 11$$,
    '23514', 'contacts_name_not_blank');
SELECT pg_temp.expect_rejected('N10 invalid contact email',
    $$UPDATE crm_demo.contacts SET email = 'invalid' WHERE contact_id = 11$$,
    '23514', 'contacts_email_shape');
SELECT pg_temp.expect_rejected('N11 null contact account',
    $$UPDATE crm_demo.contacts SET account_id = NULL WHERE contact_id = 11$$, '23502');
SELECT pg_temp.expect_rejected('N12 missing opportunity contact',
    $$UPDATE crm_demo.opportunities SET contact_id = 999 WHERE opportunity_id = 101$$,
    '23503', 'opportunities_contact_account_fk');
SELECT pg_temp.expect_rejected('N13 contact from another account',
    $$UPDATE crm_demo.opportunities SET contact_id = 21 WHERE opportunity_id = 101$$,
    '23503', 'opportunities_contact_account_fk');
SELECT pg_temp.expect_rejected('N14 null opportunity contact',
    $$UPDATE crm_demo.opportunities SET contact_id = NULL WHERE opportunity_id = 101$$, '23502');
SELECT pg_temp.expect_rejected('N15 zero amount',
    $$UPDATE crm_demo.opportunities SET amount = 0 WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N16 negative amount',
    $$UPDATE crm_demo.opportunities SET amount = -0.01 WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N17 fractional cent',
    $$UPDATE crm_demo.opportunities SET amount = 1.001 WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N18 amount above maximum',
    $$UPDATE crm_demo.opportunities SET amount = 1000000000 WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N19 numeric NaN',
    $$UPDATE crm_demo.opportunities SET amount = 'NaN'::numeric WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N20 positive infinity',
    $$UPDATE crm_demo.opportunities SET amount = 'Infinity'::numeric WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N21 negative infinity',
    $$UPDATE crm_demo.opportunities SET amount = '-Infinity'::numeric WHERE opportunity_id = 101$$,
    '23514', 'opportunities_amount_valid');
SELECT pg_temp.expect_rejected('N22 null amount',
    $$UPDATE crm_demo.opportunities SET amount = NULL WHERE opportunity_id = 101$$, '23502');
SELECT pg_temp.expect_rejected('N23 unsupported currency',
    $$UPDATE crm_demo.opportunities SET currency = 'GBP' WHERE opportunity_id = 101$$,
    '23514', 'opportunities_currency_valid');
SELECT pg_temp.expect_rejected('N24 unsupported stage',
    $$UPDATE crm_demo.opportunities SET stage = 'pending' WHERE opportunity_id = 102$$,
    '23514', 'opportunities_stage_valid');
SELECT pg_temp.expect_rejected('N25 won without closing date',
    $$UPDATE crm_demo.opportunities SET closed_on = NULL WHERE opportunity_id = 101$$,
    '23514', 'opportunities_closure_consistent');
SELECT pg_temp.expect_rejected('N26 open opportunity with closing date',
    $$UPDATE crm_demo.opportunities SET closed_on = DATE '2026-04-06' WHERE opportunity_id = 102$$,
    '23514', 'opportunities_closure_consistent');
SELECT pg_temp.expect_rejected('N27 close before opening',
    $$UPDATE crm_demo.opportunities SET closed_on = DATE '2026-03-31' WHERE opportunity_id = 101$$,
    '23514', 'opportunities_dates_ordered');
SELECT pg_temp.expect_rejected('N28 delete referenced contact',
    $$DELETE FROM crm_demo.contacts WHERE contact_id = 11$$,
    '23503', 'opportunities_contact_account_fk');
SELECT pg_temp.expect_rejected('N29 move referenced contact to another account',
    $$UPDATE crm_demo.contacts SET account_id = 2 WHERE contact_id = 11$$,
    '23503', 'opportunities_contact_account_fk');
SELECT pg_temp.expect_rejected('N30 blank opportunity title',
    $$UPDATE crm_demo.opportunities SET title = '  ' WHERE opportunity_id = 101$$,
    '23514', 'opportunities_title_not_blank');

SELECT pg_temp.expect_true('P07 failed updates left original amount', (
    SELECT amount = 1200 FROM crm_demo.opportunities WHERE opportunity_id = 101
));
SELECT pg_temp.expect_true('P08 failed inserts left account count', (SELECT count(*) = 3 FROM crm_demo.accounts));
SELECT pg_temp.expect_true('P09 failed inserts and deletes left contact count', (SELECT count(*) = 4 FROM crm_demo.contacts));

-- Happy-path boundary cases also run within the outer rollback-only transaction.
INSERT INTO crm_demo.contacts VALUES (99, 2, 'Shared mailbox example', 'alex@cedar.test');
SELECT pg_temp.expect_true('P10 same email allowed in different accounts', (
    SELECT count(*) = 2 FROM crm_demo.contacts WHERE email = 'alex@cedar.test'
));
DELETE FROM crm_demo.contacts WHERE contact_id = 99;

UPDATE crm_demo.opportunities SET amount = 0.01 WHERE opportunity_id = 102;
SELECT pg_temp.expect_true('P11 smallest allowed amount', (
    SELECT amount = 0.01 FROM crm_demo.opportunities WHERE opportunity_id = 102
));
UPDATE crm_demo.opportunities SET amount = 999999999.99 WHERE opportunity_id = 102;
SELECT pg_temp.expect_true('P12 largest allowed amount', (
    SELECT amount = 999999999.99 FROM crm_demo.opportunities WHERE opportunity_id = 102
));
UPDATE crm_demo.opportunities SET stage = 'won', closed_on = opened_on WHERE opportunity_id = 102;
SELECT pg_temp.expect_true('P13 same-day close and valid stage transition', (
    SELECT stage = 'won' AND closed_on = opened_on FROM crm_demo.opportunities WHERE opportunity_id = 102
));
UPDATE crm_demo.opportunities SET amount = 300, stage = 'qualified', closed_on = NULL WHERE opportunity_id = 102;

-- Test the helper itself. These calls must fail rather than report a false pass.
DO $$
DECLARE helper_failed boolean := false;
BEGIN
    BEGIN
        PERFORM pg_temp.expect_rejected('must not pass accepted SQL', 'SELECT 1', '23505');
    EXCEPTION WHEN raise_exception THEN helper_failed := true;
    END;
    PERFORM pg_temp.expect_true('P14 rejection helper detects accepted SQL', helper_failed);
    helper_failed := false;
    BEGIN
        PERFORM pg_temp.expect_rejected('must not pass wrong error', 'SELECT 1 / 0', '23505');
    EXCEPTION WHEN raise_exception THEN helper_failed := true;
    END;
    PERFORM pg_temp.expect_true('P15 rejection helper detects wrong SQLSTATE', helper_failed);
END;
$$;

SELECT test_name, passed FROM pg_temp.test_results ORDER BY test_name;
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_temp.test_results) <> 45 THEN
        RAISE EXCEPTION 'FAIL expected exactly 45 checks';
    END IF;
END;
$$;
SELECT count(*) AS passed_checks FROM pg_temp.test_results;
