// "Remove closed issues": closing an issue takes it off a list with the
// option and leaves it on a list without; switching the option on later
// takes off the closed issues the list already holds.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('remove_closed');
const stamp = Date.now();

async function newIssue(subject, lists) {
  await t.go(`/projects/${P}/issues/new`);
  await t.page.fill('#issue_subject', subject);
  const values = [];
  for (const title of lists) values.push(await t.page.locator('#issue_issue_todo_list_ids option', { hasText: title }).getAttribute('value'));
  await t.page.selectOption('#issue_issue_todo_list_ids', values);
  await t.page.click('#issue-form input[name=commit]');
  await t.settle();
  t.check(`create ${subject}`);
  return t.page.url().match(/\/issues\/(\d+)/)[1];
}
// The seeded role has no workflow, so the administrator closes the issue.
async function close(id) {
  await t.login('admin');
  await t.go(`/issues/${id}/edit`);
  const closed = await t.page.locator('#issue_status_id option', { hasText: /^Closed$/ }).first().getAttribute('value');
  await t.page.selectOption('#issue_status_id', closed);
  await t.settle();
  await t.page.click('#issue-form input[name=commit]');
  await t.settle();
  t.check(`close ${id}`);
  const json = await (await t.page.request.get(`${t.BASE}/issues/${id}.json`)).json();
  if (!json.issue.closed_on) t.problems.push(`close ${id}: the issue is not closed (${t.page.url()})`);
}
async function listedOn(title) {
  await t.go(`/projects/${P}/issue_todo_lists`);
  await t.page.click(`table.list a:text-is("${title}")`);
  await t.settle();
  return t.page.locator('#issue-todo-list-table td.id a').allInnerTexts();
}

await t.login('manager');
const id = await newIssue(`E2E to close ${stamp}`, ['E2E cleanup', 'E2E sprint']);
if (!(await listedOn('E2E cleanup')).includes(id)) t.problems.push('setup: issue not on E2E cleanup');
await t.shot('before-close', 'An open issue on E2E cleanup (removes closed issues) and on E2E sprint');
await close(id);
await t.shot('closed', 'The administrator closes the issue; the sidebar still shows it on E2E sprint (remove button), no longer on E2E cleanup');
await t.login('manager');
if ((await listedOn('E2E cleanup')).includes(id)) t.problems.push('close: still on E2E cleanup');
await t.shot('cleanup-after', 'E2E cleanup no longer holds the closed issue');
if (!(await listedOn('E2E sprint')).includes(id)) t.problems.push('close: taken off E2E sprint as well');
await t.shot('sprint-after', 'E2E sprint, without the option, keeps the closed issue');

// A new list without the option, holding a closed issue; then switch it on.
const id2 = await newIssue(`E2E closed before the option ${stamp}`, []);
await close(id2);
await t.login('manager');
await t.go(`/projects/${P}/issue_todo_lists/new`);
await t.page.fill('#issue_todo_list_title', `E2E option later ${stamp}`);
await t.page.click('#content input[name=commit]');
await t.settle();
const listPath = new URL(t.page.url()).pathname;
await t.page.fill('#item_issue_id', id2);
await t.page.click('#new-item-form input[type=submit]');
await t.page.waitForResponse(r => r.url().includes('/items') && r.request().method() === 'POST');
await t.settle();
if (!(await t.page.locator('#issue-todo-list-table td.id a', { hasText: id2 }).count())) t.problems.push('setup: closed issue not added');
await t.shot('option-off', 'A list without the option accepts a closed issue');
await t.go(`${listPath}/edit`);
await t.page.check('#issue_todo_list_remove_closed_issues');
await t.page.click('#content input[name=commit]');
await t.settle();
t.check('switch on');
if (await t.page.locator('#issue-todo-list-table td.id a', { hasText: id2 }).count()) t.problems.push('option on: closed issue still listed');
await t.shot('option-on', 'Switching the option on takes the closed issue off the list at once');

await t.done();
