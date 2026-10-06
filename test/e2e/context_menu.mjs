// The "To-do lists" folder of the issue context menu: add one issue, unlist
// it again, and the bulk entries for several issues (add all, partly listed,
// unlist all). No folder for members without the permission.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('context_menu');

async function issueId(subject) {
  const r = await t.page.request.get(`${t.BASE}/issues.json?project_id=${P}&status_id=*&subject=${encodeURIComponent(subject)}`);
  const issue = (await r.json()).issues.find(i => i.subject === subject);
  if (!issue) throw new Error(`no issue "${subject}"`);
  return issue.id;
}
async function openMenu(ids) {
  await t.go(`/projects/${P}/issues?set_filter=1&status_id=*&sort=id`);
  for (const [i, id] of ids.entries()) {
    await t.page.click(`tr#issue-${id} td.status`, { modifiers: i ? ['ControlOrMeta'] : [] });
  }
  await t.page.click(`tr#issue-${ids[ids.length - 1]} td.status`, { button: 'right' });
  await t.page.waitForSelector('#context-menu ul', { timeout: 10000 });
  t.check('open menu');
}
async function openFolder() {
  const folder = t.page.locator('#context-menu li.folder', { has: t.page.locator('> a.submenu', { hasText: 'To-do lists' }) });
  await folder.hover();
  return folder;
}
async function listed(listTitle) {
  await t.go(`/projects/${P}/issue_todo_lists`);
  await t.page.click(`table.list a:text-is("${listTitle}")`);
  await t.settle();
  return t.page.locator('#issue-todo-list-table td.id a').allInnerTexts();
}

await t.login('manager');
const related = await issueId('E2E related issue');
const subtask = await issueId('E2E subtask');
const assigned = await issueId('E2E assigned issue');

await openMenu([related]);
const folder = await openFolder();
const entry = folder.locator('ul li', { hasText: 'E2E sprint' });
if (!(await entry.locator('a.icon-add').count())) t.problems.push('single issue: no add entry for E2E sprint');
await t.shot('single-add', 'One issue not on E2E sprint: the folder offers to add it to each list', { full: false });
await entry.locator('a').click();
await t.settle();
t.check('add one');
if (!/\/issues/.test(t.page.url())) t.problems.push(`add one: back on ${t.page.url()}`);
if (!(await listed('E2E sprint')).includes(String(related))) t.problems.push('add one: issue not on the list');
await t.shot('single-added', 'The issue is now on E2E sprint');

await openMenu([related]);
const unlist = (await openFolder()).locator('ul li', { hasText: 'E2E sprint' });
if (!(await unlist.locator('a.icon-del').count())) t.problems.push('single issue: no unlist entry');
await t.shot('single-unlist', 'The same issue: the folder now offers to take it off E2E sprint', { full: false });
await unlist.locator('a').click();
await t.settle();
t.check('unlist one');
if ((await listed('E2E sprint')).includes(String(related))) t.problems.push('unlist one: issue still on the list');

// Two issues, one of them on E2E sprint already: a partial add.
await openMenu([assigned, subtask]);
const some = (await openFolder()).locator('ul li', { hasText: 'E2E sprint' });
if (!(await some.locator('a.icon-warning').count())) t.problems.push('bulk: no partial-add entry');
const someTitle = await some.getAttribute('title');
await t.shot('bulk-partial', `Two issues, one listed: a warning entry adds the other ("${someTitle}")`, { full: false });
await some.locator('a').click();
await t.settle();
t.check('bulk add');
const now = await listed('E2E sprint');
if (!now.includes(String(subtask)) || !now.includes(String(assigned))) t.problems.push(`bulk add: list holds ${now}`);
await t.shot('bulk-added', 'Both issues are on E2E sprint, the one that was there kept its place');

await openMenu([assigned, subtask]);
const all = (await openFolder()).locator('ul li', { hasText: 'E2E sprint' });
if (!(await all.locator('a.icon-del').count())) t.problems.push('bulk: no unlist-all entry');
await t.shot('bulk-unlist', 'Both listed: the entry takes both off the list', { full: false });
await all.locator('a').click();
await t.settle();
const after = await listed('E2E sprint');
if (after.includes(String(subtask)) || after.includes(String(assigned))) t.problems.push(`bulk unlist: list holds ${after}`);
// Put the seed issue back at the end, so the run can be repeated.
await openMenu([assigned]);
await (await openFolder()).locator('ul li', { hasText: 'E2E sprint' }).locator('a').click();
await t.settle();

for (const user of ['viewer', 'reporter']) {
  await t.login(user);
  await openMenu([related]);
  if (await t.page.locator('#context-menu a.submenu', { hasText: 'To-do lists' }).count()) t.problems.push(`${user} sees the folder`);
  await t.shot(`${user}-no-folder`, `${user === 'viewer' ? 'A view-only member' : 'A member without the plugin\'s permissions'} gets the core menu without the To-do lists folder`, { full: false });
}

await t.done();
