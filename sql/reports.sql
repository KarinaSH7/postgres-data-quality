-- Won values are business outcomes in this fictional CRM, not accounting revenue.
-- Keep currencies separate. No exchange rates or currency conversion are assumed.
SELECT currency, stage, count(*) AS opportunity_count, sum(amount) AS total_amount
FROM crm_demo.opportunities
GROUP BY currency, stage
ORDER BY currency, stage;

SELECT a.company_name, o.currency,
       count(*) FILTER (WHERE o.stage IN ('new', 'qualified')) AS open_count,
       coalesce(sum(o.amount) FILTER (WHERE o.stage IN ('new', 'qualified')), 0) AS open_amount,
       coalesce(sum(o.amount) FILTER (WHERE o.stage = 'won'), 0) AS won_amount
FROM crm_demo.accounts AS a
JOIN crm_demo.opportunities AS o USING (account_id)
GROUP BY a.company_name, o.currency
ORDER BY a.company_name, o.currency;

-- Validation report. All values should be zero for the supplied fixtures.
-- These read-only checks also illustrate how to inspect imported legacy data.
SELECT
    (SELECT count(*) FROM crm_demo.contacts AS c
     LEFT JOIN crm_demo.accounts AS a USING (account_id)
     WHERE a.account_id IS NULL) AS orphan_contacts,
    (SELECT count(*) FROM crm_demo.opportunities AS o
     LEFT JOIN crm_demo.contacts AS c
       ON c.contact_id = o.contact_id AND c.account_id = o.account_id
     WHERE c.contact_id IS NULL) AS invalid_contact_account_pairs,
    (SELECT count(*) FROM crm_demo.opportunities
     WHERE amount IS NULL OR NOT (
         amount > 0 AND amount <= 999999999.99 AND amount = round(amount, 2)
     )) AS invalid_amounts,
    (SELECT count(*) FROM (
        SELECT billing_email FROM crm_demo.accounts
        GROUP BY billing_email HAVING count(*) > 1
    ) AS duplicates) AS duplicate_billing_emails;
