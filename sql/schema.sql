-- Isolated fictional CRM. Deliberately fails if this schema already exists.
CREATE SCHEMA crm_demo;

CREATE TABLE crm_demo.accounts (
    account_id bigint PRIMARY KEY,
    company_name text NOT NULL,
    billing_email text NOT NULL,
    created_on date NOT NULL,
    CONSTRAINT accounts_company_name_not_blank CHECK (btrim(company_name) <> ''),
    CONSTRAINT accounts_email_normalized CHECK (billing_email = lower(btrim(billing_email))),
    CONSTRAINT accounts_email_shape CHECK (
        billing_email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    ),
    CONSTRAINT accounts_billing_email_unique UNIQUE (billing_email)
);

CREATE TABLE crm_demo.contacts (
    contact_id bigint PRIMARY KEY,
    account_id bigint NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    CONSTRAINT contacts_account_fk FOREIGN KEY (account_id)
        REFERENCES crm_demo.accounts (account_id) ON DELETE RESTRICT,
    CONSTRAINT contacts_name_not_blank CHECK (btrim(full_name) <> ''),
    CONSTRAINT contacts_email_normalized CHECK (email = lower(btrim(email))),
    CONSTRAINT contacts_email_shape CHECK (
        email ~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    ),
    CONSTRAINT contacts_account_email_unique UNIQUE (account_id, email),
    -- Supports the composite foreign key on opportunities.
    CONSTRAINT contacts_id_account_unique UNIQUE (contact_id, account_id)
);

CREATE TABLE crm_demo.opportunities (
    opportunity_id bigint PRIMARY KEY,
    account_id bigint NOT NULL,
    contact_id bigint NOT NULL,
    title text NOT NULL,
    amount numeric NOT NULL,
    currency text NOT NULL,
    stage text NOT NULL,
    opened_on date NOT NULL,
    closed_on date,
    CONSTRAINT opportunities_account_fk FOREIGN KEY (account_id)
        REFERENCES crm_demo.accounts (account_id) ON DELETE RESTRICT,
    CONSTRAINT opportunities_contact_account_fk FOREIGN KEY (contact_id, account_id)
        REFERENCES crm_demo.contacts (contact_id, account_id) ON DELETE RESTRICT,
    CONSTRAINT opportunities_title_not_blank CHECK (btrim(title) <> ''),
    -- No numeric(p, 2) coercion. Reject excess precision instead of rounding it.
    -- The upper bound also rejects PostgreSQL numeric NaN and Infinity.
    CONSTRAINT opportunities_amount_valid CHECK (
        amount > 0 AND amount <= 999999999.99 AND amount = round(amount, 2)
    ),
    CONSTRAINT opportunities_currency_valid CHECK (currency IN ('USD', 'EUR')),
    CONSTRAINT opportunities_stage_valid CHECK (stage IN ('new', 'qualified', 'won', 'lost')),
    CONSTRAINT opportunities_closure_consistent CHECK (
        (stage IN ('won', 'lost')) = (closed_on IS NOT NULL)
    ),
    CONSTRAINT opportunities_dates_ordered CHECK (closed_on IS NULL OR closed_on >= opened_on)
);

-- PostgreSQL does not automatically index the referencing side of a foreign key.
CREATE INDEX contacts_account_idx ON crm_demo.contacts (account_id);
CREATE INDEX opportunities_contact_account_idx ON crm_demo.opportunities (contact_id, account_id);
CREATE INDEX opportunities_account_idx ON crm_demo.opportunities (account_id);
