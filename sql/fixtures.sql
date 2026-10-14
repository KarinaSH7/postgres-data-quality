-- Invented businesses and contacts. The reserved .test domain cannot identify real customers.
-- Explicit stable IDs make test failures easy to reproduce. No generated identity sequence.
INSERT INTO crm_demo.accounts (account_id, company_name, billing_email, created_on) VALUES
    (1, 'Cedar Workshop', 'billing@cedar.test', DATE '2026-01-10'),
    (2, 'Harbor Studio', 'billing@harbor.test', DATE '2026-02-01'),
    (3, 'Meadow Books', 'billing@meadow.test', DATE '2026-03-15');

INSERT INTO crm_demo.contacts (contact_id, account_id, full_name, email) VALUES
    (11, 1, 'Alex Cedar', 'alex@cedar.test'),
    (12, 1, 'Sam Cedar', 'sam@cedar.test'),
    (21, 2, 'Robin Harbor', 'robin@harbor.test'),
    (31, 3, 'Jamie Meadow', 'jamie@meadow.test');

INSERT INTO crm_demo.opportunities
    (opportunity_id, account_id, contact_id, title, amount, currency, stage, opened_on, closed_on)
VALUES
    (101, 1, 11, 'Inventory setup', 1200.00, 'USD', 'won', DATE '2026-04-01', DATE '2026-04-10'),
    (102, 1, 12, 'Monthly support', 300.00, 'USD', 'qualified', DATE '2026-04-05', NULL),
    (201, 2, 21, 'Booking prototype', 850.00, 'EUR', 'new', DATE '2026-04-07', NULL),
    (202, 2, 21, 'Legacy data review', 450.00, 'EUR', 'lost', DATE '2026-04-08', DATE '2026-04-15'),
    (301, 3, 31, 'Catalog cleanup', 600.00, 'USD', 'won', DATE '2026-04-09', DATE '2026-04-20');
