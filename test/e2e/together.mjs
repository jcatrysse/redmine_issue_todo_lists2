// The pages that broke when another plugin's prepend met this plugin's
// alias_method chain (decided by Jan 2026-10-07: prepend): Project > Settings,
// the issue list with this plugin's filter, columns and sort, and an issue
// page, as every user. Run it on a Redmine with the other GEOxyz plugins too.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const name = process.env.RMP_E2E_NAME || 'together';
const t = await e2e(name);
const list = `/projects/${P}/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=*&f[]=status_id&op[status_id]=*` +
  '&c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions';
const titles = () => t.page.locator('table.issues td.issue_todo_list_titles-titles a').count();

async function issueId(subject) {
  const r = await t.page.request.get(`${t.BASE}/issues.json?project_id=${P}&status_id=*&subject=${encodeURIComponent(subject)}`);
  return (await r.json()).issues.find(i => i.subject === subject).id;
}

for (const user of ['admin', 'manager']) {
  await t.login(user);
  await t.go(`/projects/${P}/settings`);
  await t.sudo();
  await t.shot(`${user}-project-settings`, `Project > Settings answers 200 for ${user}`);
  await t.go(list);
  if (!(await titles())) t.problems.push(`${user}: issue list without to-do list titles`);
  await t.shot(`${user}-issue-list`, `The issue list filtered on "any to-do list", with the titles and order columns, sorted on the order, as ${user}`);
  await t.go(`/issues/${await issueId('E2E assigned issue')}`);
  if (!(await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count())) t.problems.push(`${user}: no sidebar block`);
  await t.shot(`${user}-issue`, `An issue page with the to-do list block, as ${user}`);
}

await t.login('reporter');
await t.go(`/projects/${P}/settings`, { status: 403 });
await t.shot('reporter-project-settings-refused', 'Project > Settings is refused to a member without the permission (403)');
await t.go(list);
if (await t.page.locator('table.issues td.issue_todo_list_titles-titles').count()) t.problems.push('reporter gets the titles column');
await t.shot('reporter-issue-list', 'The same issue list URL works for a member without the plugin\'s permissions, without the filter and columns');
await t.go(`/issues/${await issueId('E2E assigned issue')}`);
if (await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count()) t.problems.push('reporter sees the sidebar block');
await t.shot('reporter-issue', 'The issue page answers 200 without the to-do list block');

await t.login('outsider');
await t.go('/projects/e2e-private/settings', { status: 403 });
await t.go('/projects/e2e-private/issues', { status: 403 });
await t.shot('outsider-private-refused', 'The private project\'s issue list is refused to a non-member (403)');
await t.go(list);
if (await t.page.locator('table.issues td.issue_todo_list_titles-titles').count()) t.problems.push('outsider gets the titles column');
await t.shot('outsider-issue-list', 'The public project\'s issue list answers 200 for a non-member, without the plugin\'s columns');

await t.done();
