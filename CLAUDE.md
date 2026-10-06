# CLAUDE.md: redmine_issue_todo_lists2

Redmine plugin `redmine_issue_todo_lists2`, run by GEOxyz. Upstream: geen. GEOxyz production branch: `master`.

**Current work: the migration to Redmine 7.** Read
[docs/REDMINE7-MIGRATION.md](docs/REDMINE7-MIGRATION.md) before anything else; it holds the plan,
the measured state, the work list and the rules. Work on branch `redmine70-migration`.

## Always

- Run commands yourself (tests, linters, `rails runner`, a browser) and quote the results. Never
  call something green you did not see green.
- Never skip, delete or weaken a test. Every fix gets a test that fails without it.
- Minimal diffs in this plugin's style; no reformatting, no drive-by refactoring.
- Authorization on every action, `safe_attributes` instead of mass assignment, no SQL from
  params, no secrets in logs, no `html_safe` on user input.
- PostgreSQL and MySQL/MariaDB both supported; migrations reversible.
- I18n for every user-visible string; keep the shipped locales in sync, translated by matching
  existing keys in the same file; no new languages.
- Compare with Redmine core before patching it: https://github.com/jcatrysse/redmine
  (`5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`).
- GitHub Actions are manual only (`workflow_dispatch`); never add automatic triggers.
- Never push to the default branch, never force-push a shared branch.

## Testing

This repo already has its own `.codex/` scripts (older variant). Read their headers and use them; check they accept `7.0-stable-GEOxyz` (clone from https://github.com/jcatrysse/redmine.git) and MariaDB. The shared variant from the other plugin repos may replace them if that is simpler.

## For a new task after the migration

Use the four-role approach (implement, independent review, QA, UX/consistency) and the gates in
docs/REDMINE7-MIGRATION.md ("Rules" and "Definition of done") for any change in this repo.
