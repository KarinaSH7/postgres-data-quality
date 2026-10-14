#!/usr/bin/env python3
"""Check repository structure only. This does not parse or execute PostgreSQL SQL."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL {message}")


for name in (
    "README.md", "VALIDATION.md", "compose.yaml", "docs/test-plan.md",
    "docs/explanation-guide.md", "scripts/run_checks.sh", "sql/schema.sql",
    "sql/fixtures.sql", "sql/tests.sql", "sql/reports.sql", "sql/run_checks.sql",
):
    require((ROOT / name).is_file(), f"missing {name}")

runner = (ROOT / "sql/run_checks.sql").read_text()
require("\\set ON_ERROR_STOP on" in runner, "runner must stop on SQL errors")
require("BEGIN;" in runner and "ROLLBACK;" in runner, "rollback-only transaction missing")
require(not re.search(r"^\s*COMMIT\s*;", runner, re.M | re.I), "runner must not commit")
includes = re.findall(r"^\\ir (.+)$", runner, re.M)
require(includes == ["schema.sql", "fixtures.sql", "tests.sql", "reports.sql"], "unexpected SQL include order")
for name in includes:
    require((ROOT / "sql" / name).is_file(), f"missing included SQL file {name}")

schema = (ROOT / "sql/schema.sql").read_text()
tests = (ROOT / "sql/tests.sql").read_text()
ids = re.findall(r"expect_(?:true|rejected)\('(P\d{2}|N\d{2})\b", tests)
expected = {f"P{i:02}" for i in range(1, 16)} | {f"N{i:02}" for i in range(1, 31)}
require(len(ids) == len(set(ids)) == 45, "expected 45 unique authored check IDs")
require(set(ids) == expected, "test ID coverage changed")
constraints = set(re.findall(r"CONSTRAINT\s+(\w+)", schema)) | {"accounts_pkey"}
referenced = re.findall(r"'235(?:03|05|14)', '([a-z_]+)'", tests)
require(set(referenced) <= constraints, "a test refers to an undeclared constraint")
require("DROP SCHEMA" not in schema.upper(), "schema must not delete existing data")
require("CREATE SCHEMA crm_demo;" in schema, "isolated schema missing")

compose = (ROOT / "compose.yaml").read_text()
require("network_mode: none" in compose, "container networking must be disabled")
require(not re.search(r"^\s*ports:", compose, re.M), "demo must not publish a port")
require('"listen_addresses="' in compose, "TCP listener must be disabled")

for path in ROOT.rglob("*.md"):
    text = path.read_text()
    require("—" not in text and "–" not in text, f"long dash in {path.name}")
    for link in re.findall(r"\]\(([^)]+)\)", text):
        if not link.startswith(("https://", "http://", "#")):
            require((path.parent / link.split("#", 1)[0]).is_file(), f"broken link {link}")

print("PASS repository structure, 45 authored check IDs, named constraints, local links, and safety settings")
print("NOT RUN PostgreSQL SQL execution and Docker Compose startup")
