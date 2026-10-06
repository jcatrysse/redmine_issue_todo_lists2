# Redmine 7 migration: redmine_issue_todo_lists2

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL and MariaDB, every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_issue_todo_lists2` |
| GEOxyz runs today | `master` |
| Upstream | geen |
| Runs on Redmine 7 as is | JA (confirmed end to end in a browser, see "Results") |
| Upstream sync | GEEN UPSTREAM |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 1 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz @ `8067e23`), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16.15 and MariaDB 10.11.14 |
| Migration session | 2026-10-06, done: no plugin code change needed; tests, e2e and review below |

## Already on this branch

- `test/e2e/`: seed and 12 end-to-end scenarios, one per function (inventory below).
- `docs/e2e/`: screenshots and tables of the clean PostgreSQL run; `docs/e2e/mariadb/` the MariaDB run;
  `docs/e2e/mariadb-semijoin-on/` the evidence of the MariaDB optimizer bug (see "After the upgrade").
- `.codex/start_server.sh`: grants the e2e database to the MariaDB account `test_setup.sh` creates
  (it was refused with "Access denied for 'redmine'@'127.0.0.1'").
- No change to the plugin's own code (`app/`, `lib/`, `config/`, `db/`, `assets/`, `init.rb`).

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Open items from the analysis** (Dutch; where they conflict with a decision or a priority item above, those win)

1. lijstpagina (drag-sortering) en toevoegen via context-menu met de hand testen op 7.0; smoke bereikte alleen de index-pagina's
   **DONE.** `test/e2e/ordering.mjs` sleept met de muis (jQuery UI sortable), de volgorde blijft na herladen;
   `test/e2e/context_menu.mjs` voegt toe en haalt weg voor 1 en 2 issues (ook de gedeeltelijke variant).
   Beide groen op PostgreSQL en MariaDB, met en zonder rechten.
2. todolists_with_positions in Liquid hangt alleen aan RedmineCrm::Liquid::IssueDrop; zonder redmineup (reporter_dashboards standalone) niet bereikbaar in sjablonen
   **Bevestigd, niet veranderd; keuze voor Jan (zie "Open questions for Jan").** Gemeten met
   `redmine_reporter_dashboards@redmine70-migration` (`a167c70`) erbij: `TodoListsDrop` geladen, `RedmineCrm=nil`,
   `RedmineReporterDashboards::Liquid::Drops::IssueDrop.method_defined?(:todolists_with_positions)` = `false`.
   reporter_dashboards houdt zijn sjabloonwoordenschat bewust zelf bij (zijn eigen werklijst-item 7).
   Deze plugin biedt `Issue#todolists_with_positions(user)` (respecteert de rechten van `user`,
   spec `models_spec.rb:116`), dus reporter_dashboards kan het zelf aanbieden met zijn eigen actor.

**Checks**

3. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
   **DONE** on 7.0 (numbers under "Results"). 5.1: **not run**: this branch changes no plugin code, so
   master's 5.1 support (README, 2.4.0) is unaffected; Redmine 5.1 also needs Ruby < 3.3 and only 3.3.6 is
   in this container.
4. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
   **DONE, nothing needed.** Core renders `app/views/issues/show.api.rsb` from `Rails.root` for the payload; this
   plugin adds nothing to the issue API and changes no issue data (list membership is its own table), so
   webhooks and the REST API agree. `test/e2e/webhooks.mjs` points a real webhook at a listener: the issue
   form putting an issue on a list sends `issue.updated`, closing it (which takes it off a list that removes
   closed issues) sends `issue.closed` and `issue.updated`; no to-do list fields in the payload
   (`docs/e2e/webhooks-payloads.json`). Changing a list (items, order) sends no webhook, as there is no
   webhook event for plugin objects.
5. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).
   **DONE**: inventory below, every screenshot looked at.

**Found while testing (pre-existing, not Redmine 7 related, not fixed: rule "do not fix in passing")**

6. A text item's field is only shown when the same column is also chosen for issue items: choosing
   "Due date" for text items alone stores the value but shows it nowhere (list, CSV), only in the API.
   The scenario `items.mjs` therefore also ticks the issue column.
7. Text item dates are shown raw (`2026-12-24`), not in the user's date format like issue dates.
8. "Add issue" with an unknown number says "The issue was not found or does not belong to this project",
   while issues of other projects are accepted (cross-project lists).
9. The settings page says "todo lists" (`label_show_in_issue_sidebar` etc.) where the rest says "To-do lists".
10. `GET .../items/:id/edit` answers only JS; a direct HTML request gives 406 with an empty page
    (smoke screenshot 12). Correct, not a server error; listed so nobody reads the blank picture as a bug.

## Results

**Baseline, before any change** (branch head `808d8af`, same as master `fd8fb75` for the code):

| | PostgreSQL 16.15 | MariaDB 10.11.14 |
|---|---|---|
| `./.codex/test_plugin.sh` | 140 examples, 0 failures, 1 pending | 140 examples, 0 failures, 2 pending |
| migrations down to 0 and up (test) | OK | OK |
| `./.codex/e2e.sh` (smoke + core, no scenarios yet) | smoke 16 pages, core 6 shots, 0 problems | not run before the scenarios existed |

Pending: `context_menu_spec.rb:222` (only meaningful on 5.1), and on MariaDB also `migrations_spec.rb:18`
(PostgreSQL only by design).

**Final** (plugin code unchanged, so the spec numbers are the same):

| | PostgreSQL 16.15 | MariaDB 10.11.14 |
|---|---|---|
| specs | 140 / 0 failures / 1 pending | 140 / 0 failures / 2 pending |
| e2e, `start_server.sh --reset` then `e2e.sh` | 14 scripts, 92 screenshots, 0 problems (`docs/e2e/`) | default optimizer: 11 of 14 green, 3 fail on a MariaDB bug (below); with `semijoin=off`: 14 scripts, 92 screenshots, 0 problems (`docs/e2e/mariadb/`) |
| together with `redmine_reporter_dashboards@redmine70-migration` | migrations, eager load OK; specs 140/0/1; e2e 14 scripts, 0 problems | not run |

**MariaDB 10.11.14 optimizer bug (not this plugin).** With the default `optimizer_switch`, core's issue
query returns no rows for a member of a public project whose role sees all issues (`viewer` in the seed):
an empty issue list in core, and lists that show only their text items to that user (the plugin filters
items through `Issue.visible`). `docs/e2e/mariadb-semijoin-on/repro.sql` is core SQL only and gives 0 instead
of 6; with `SET optimizer_switch='semijoin=off'` (or `materialization=off`) it gives 6, and the whole e2e set is
green. Plugin specs do not hit it (fixtures differ). See "After the upgrade".

## Inventory of functions

Scenario scripts in `test/e2e/`, screenshots in `docs/e2e/<scenario>-*.png` with a caption table in
`docs/e2e/<scenario>.md`. Users: admin, manager (every permission), viewer (seed: may only view lists),
reporter (no plugin permission), outsider (no membership), anonymous.

| function | how a user reaches it | scenario | screenshots (paths covered) |
|---|---|---|---|
| Project menu, index of lists | project menu "To-do lists" | `lists.mjs` | index, index-viewer (no New), index-reporter-refused (403, no menu), private-outsider-refused (403), private-anonymous-login |
| Create, edit, delete a list | New / Edit / Delete on the list | `lists.mjs` | create-blank-title (refused), create-form, created, edited, deleted, new-viewer-refused (403), show-viewer (no tools) |
| Add items (issue by number, with #, text item) | "Add issue" form on the list | `items.mjs` | added, unknown-issue-refused, empty-item-refused, closed-issue-refused, viewer (no form; POST 403) |
| Edit comment and text item fields | pencil on an item | `items.mjs` | edit-comment-form, edit-text-item-form, edited |
| Remove an item | broken-link icon on an item | `items.mjs` | removed (order stays 1..n) |
| Order by drag and drop | drag a row | `ordering.mjs` | before, dragged, reloaded, viewer-not-sortable (POST 403) |
| Issue context menu folder | right click in the issue list | `context_menu.mjs` | single-add, single-added, single-unlist, bulk-partial, bulk-added, bulk-unlist, viewer-no-folder, reporter-no-folder |
| Issue sidebar block | issue page | `issue_sidebar.mjs` | manager, added, removed, viewer (check mark only), reporter (no block), closed-issue (no add) |
| Issue form field (new and edit) | issue form | `issue_form.mjs` | new-form, new-listed, edit-form, edited, invalid-kept (validation error keeps choice, changes nothing), reporter-no-field |
| Remove closed issues | list option; closing an issue | `remove_closed.mjs` | before-close, closed, cleanup-after, sprint-after, option-off, option-on |
| Issue query filter and columns, sort | issue list filters/options | `issue_query.mjs` | filter-form, filtered, filter-none, sorted, reporter (no filter/columns even by URL) |
| CSV export | "Also available in: CSV" | `csv_api.mjs` | csv-link; content and reporter 403 in `csv_api-results.txt` |
| REST API index/show (JSON, XML) | API key | `csv_api.mjs` | `csv_api-results.txt`: 200 for manager/viewer, 403 reporter/outsider, 401 no key/bad key, POST refused |
| Plugin settings (sidebar, issue form) | Administration > Plugins > Configure | `settings.mjs` | page, off, issue-off, edit-off, edit-on, manager-refused (403) |
| User deletion hands lists to Anonymous | Administration > Users > Delete | `user_delete.mjs` | created-by-leaver, confirm-delete, deleted, list-after |
| Webhooks (Redmine 7) | My account > Webhooks | `webhooks.mjs` | new-webhook, payloads, webhook-deleted; `webhooks-payloads.json` |
| Every plugin page renders (smoke), core issue flows | | `.codex/e2e/smoke.mjs`, `core.mjs` | smoke-01..16, core-* |
| Liquid drop `todolists_with_positions` | report templates via redmineup | runner check (item 2) | none: no template engine with this drop on 7.0 without redmineup |
| Migrations (10), rollback | rake | `redmine:plugins:migrate VERSION=0` and up | PostgreSQL and MariaDB OK |

No mail, rake tasks or cron jobs in this plugin.

## Open questions for Jan

1. **Liquid `todolists_with_positions` without redmineup** (item 2). Options: (a) leave this plugin as is and let
   reporter_dashboards decide whether its IssueDrop offers to-do lists, calling
   `issue.todolists_with_positions(actor)`; (b) let this plugin patch `RedmineReporterDashboards::Liquid::Drops::IssueDrop`
   when it is loaded. Built: (a), nothing changed. Recommendation: (a). reporter_dashboards treats every public
   drop method as template vocabulary and decides it there; a patch from here would bypass that and use
   `User.current` instead of its report actor. First check whether any GEOxyz template uses
   `todolists_with_positions` at all (reporter_dashboards' plan, open item 5).
2. **MariaDB optimizer bug** (Results). Not a plugin choice, but it hits production if it runs this MariaDB
   version: who checks the production version and decides between upgrading MariaDB and setting
   `optimizer_switch='semijoin=off'`? Recommendation: run `repro.sql` against a copy of production first.

## GEOxyz changes to review or re-apply

Own plugin: all of it is GEOxyz code, so there is nothing to re-apply. While migrating, hold the code you touch to the rules below; list larger quality problems you find in the work list instead of fixing them in passing.

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Run the plugin migrations as usual (`redmine:plugins:migrate`); nothing new since 2.4.0.
- On MariaDB: check the server version. On 10.11.14 (tested here) core's issue list and this plugin's
  lists hide issues from members of public projects whose role sees all issues. Run
  `docs/e2e/mariadb-semijoin-on/repro.sql` (adapted to a real project, member and role) or simply log in
  as such a member; if issues are missing, set `optimizer_switch='semijoin=off'` in the server config or
  upgrade MariaDB. Not a plugin issue, but users will report it as one.
- Webhooks need no action for this plugin.

## How to test

This repo already has its own `.codex/` scripts (older variant). Read their headers and use them; check they accept `7.0-stable-GEOxyz` (clone from https://github.com/jcatrysse/redmine.git) and MariaDB. The shared variant from the other plugin repos may replace them if that is simpler.

Then the real Redmine and the browser checks (shared scripts, they use the checkout in `redmine/` or `REDMINE_DIR`):

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL and with MariaDB;
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
   - Run the whole e2e set once on MariaDB as well (`RMP_DB=mariadb`, then `start_server.sh --reset`).
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
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
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
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

