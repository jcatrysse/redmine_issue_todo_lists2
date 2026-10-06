# Redmine 7 migration: redmine_issue_todo_lists2

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_issue_todo_lists2` |
| GEOxyz runs today | `master` |
| Upstream | geen |
| Runs on Redmine 7 as is | JA |
| Upstream sync | GEEN UPSTREAM |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 1 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `fd8fb75` |

## Already on this branch

- nothing: the branch equals the branch GEOxyz runs today.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Open items from the analysis** (Dutch; where they repeat a priority item, the priority item wins)

1. lijstpagina (drag-sortering) en toevoegen via context-menu met de hand testen op 7.0; smoke bereikte alleen de index-pagina's
2. todolists_with_positions in Liquid hangt alleen aan RedmineCrm::Liquid::IssueDrop; zonder redmineup (reporter_dashboards standalone) niet bereikbaar in sjablonen

**Checks**

3. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
4. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
5. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

Own plugin: all of it is GEOxyz code, so there is nothing to re-apply. While migrating, hold the code you touch to the rules below; list larger quality problems you find in the work list instead of fixing them in passing.

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- None known. Add here what the session finds.

## How to test

This repo already has its own `.codex/` scripts (older variant). Read their headers and use them; check they accept `7.0-stable-GEOxyz` (clone from https://github.com/jcatrysse/redmine.git) and MariaDB. The shared variant from the other plugin repos may replace them if that is simpler.

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline**: set up Redmine 7.0-stable-GEOxyz and run the plugin's tests on PostgreSQL and
   on MariaDB (see "How to test"). Write the numbers here before you change anything.
3. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
4. **Work list**: then the numbered list, in order. One concern per commit.
5. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
6. **Browser**: start a Redmine 7 with this plugin, exercise every feature as admin and as a
   normal user with and without the plugin's permissions, and save screenshots (before on 5.1 or
   the old branch, after on 7.0) where behaviour or layout matters.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
   settings, cron, files, removed features) goes into the section "After the upgrade".
9. **Finish**: update "Status" and the work list in this file, push `redmine70-migration`, and
   report: what changed, test numbers on both databases, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service;
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint or browser check as passed without having seen it.
  Quote the summary lines. "Should work" is not a result.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module.
  The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why).
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every feature verified by hand on Redmine 7; screenshots listed.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## Analysis report (2026-10-06, Dutch)

# redmine_issue_todo_lists2
- Gebruikte branch: master @ fd8fb75 (2026-10-05, "Release 2.4.0: Redmine 7.0 support, refactoring") - plugin id `redmine_issue_todo_lists2`, versie 2.4.0, `requires_redmine version_or_higher: '5.1'`. Gemfile: alleen de test-gems `rspec` en `rspec_junit_formatter`. 10 migraties (`010_add_indexes` is nieuw in 2.4.0). 12 spec-bestanden (rspec, booten Redmine met de core-fixtures).
- Upstream: geen. Eigen plugin, gebaseerd op oude code van canidas/redmine_issue_todo_lists zonder git-relatie; die repo staat stil sinds 2020-01-18.
- Fork t.o.v. upstream: n.v.t.
- Andere relevante branches: geen (alleen master)

## 1. Werkt out of the box op Redmine 7?   JA
Harness `ROLLBACK=1 redmine_issue_todo_lists2@origin/master` (fd8fb75):
```
OK   bundle
OK   boot: redmine_issue_todo_lists2 2.4.0
OK   eager load (production-like)
OK   plugin migrations (development)
OK   plugin migrations (test)
OK   rollback to 0 and back (redmine_issue_todo_lists2)
WARN rspec redmine_issue_todo_lists2: spec/ present but no rspec in the bundle (plugin Gemfile lacks rspec-rails)
OK   smoke: 65/65 pages+actions without server error (5 plugin routes)
```
- De WARN klopt niet: het is een harness-defect, zie het eindbericht. `rspec-core` 3.13.6 zit wel in de bundle, maar er is geen `rspec`-binstub, dus `bundle exec rspec` geeft 127. **De 12 specs zijn niet gedraaid.** Een handmatige run (`ruby <rspec-core>/exe/rspec plugins/redmine_issue_todo_lists2/spec`) werd in deze sessie door de permissie-classifier geweigerd en is daarom niet opnieuw geprobeerd.
- 3x `INFO 404` op `/projects/geoxyz-verify/issue_todo_lists/1`, `/1/edit` en `/1/items/1/edit`: er bestaat geen lijst in de seed-DB. Daardoor bereikte de smoke alleen de index-pagina's, niet de lijstpagina met drag-sortering.
- Geen deprecations in `development.log`.
- **Jans claim "should be fine": statisch en voor boot, eager load, migraties, rollback en de indexpagina's bevestigd. De eigen specs en de lijstpagina zijn niet bevestigd.**

## 2. Upstream sync?   GEEN UPSTREAM

## 3. Werkt na sync op Redmine 7?   n.v.t.

## 4. Complexiteit en blokkers   score 1
- Blokkers: geen.
- Statische scan (CHECKLIST.md), alles in orde:
  - `serialize` staat achter een Rails-versie-guard: keyword-vorm vanaf 7.1 (`app/models/issue_todo_list.rb:17-23`, `issue_todo_list_item.rb:15-19`).
  - De `alias_method`-ketens op `QueriesHelper#column_content(column, item)` en `IssueQuery#initialize_available_filters`/`available_columns`/`joins_for_order_statement(order_options)` bestaan in 7.0 met dezelfde signatuur.
  - Iconen via `RedmineIssueTodoLists::Icon` (`sprite_icon` op 6+).
  - Het context-menu komt via de hook `view_issues_context_menu_end`; de plugin verwijst nergens naar `ContextMenusController`.
  - Assets via `stylesheet_link_tag`/`javascript_include_tag ..., plugin:`.
  - De JS gebruikt jQuery UI `sortable`, dat 7.0 nog meelevert (jQuery UI 1.13).
  - Geen core view-overrides.
- Liquid: `init.rb` laadt de drop zodra `::Liquid::Drop` bestaat, en de patch op `RedmineCrm::Liquid::IssueDrop` staat achter `defined?`. Gecombineerde run met `redmine_reporter_dashboards@redmine70-migration`, die de gem `liquid` meebrengt: boot, eager load en migraties OK, smoke 84/84. Runner-check: `TodoListsDrop` geladen, `RedmineCrm=nil`, patch netjes overgeslagen.
- Stille breuken: zonder redmineup is `todolists_with_positions` in Liquid-sjablonen niet meer bereikbaar. reporter_dashboards heeft een eigen drop-laag zonder deze methode. Zie het rapport van redmine_reporter_dashboards.
- Overlap met Redmine 7 core: geen.
- Open werk voor ansif:
  1. De specs draaien: `RAILS_ENV=test bundle exec rspec plugins/redmine_issue_todo_lists2/spec` (of `.codex/test_plugin.sh`). Op deze box ontbreekt de binstub; `bundle exec ruby $(bundle exec gem contents rspec-core | grep exe/rspec) ...` werkt wel.
  2. Op 7.0 met de hand een lijst aanmaken, issues toevoegen via het context-menu en drag-sorteren. De smoke kwam niet op de lijstpagina.

## Branch redmine70-migration
- Basis: origin/master @ fd8fb75
- Commits: geen (er was niets te fixen)
- Eindresultaat harness: de Q1-run hierboven, op dezelfde SHA met `ROLLBACK=1`: boot, eager load, migraties, rollback en smoke 65/65 OK; specs niet gedraaid.
- Rollback migraties: OK (10 migraties naar 0 en terug)


## Aanvulling coordinator (na harness-fix)
`OK   rspec redmine_issue_todo_lists2: 140 examples, 0 failures, 1 pending` (run 1006-092631-s4 op fd8fb75). De specs zijn daarmee wel gedraaid en groen; open punt 1 vervalt.

