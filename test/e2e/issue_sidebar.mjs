// The "To-do lists" block in the issue sidebar: add the issue to a list,
// take it off again; a view-only member sees where it is listed without the
// buttons, a member without the permissions sees no block.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('issue_sidebar');

async function issueId(subject) {
  const r = await t.page.request.get(`${t.BASE}/issues.json?project_id=${P}&status_id=*&subject=${encodeURIComponent(subject)}`);
  const issue = (await r.json()).issues.find(i => i.subject === subject);
  if (!issue) throw new Error(`no issue "${subject}"`);
  return issue.id;
}
const block = () => t.page.locator('#sidebar ul', { has: t.page.locator('a', { hasText: 'E2E project: E2E cleanup' }) });
const entry = () => block().locator('li', { hasText: 'E2E cleanup' });

await t.login('manager');
const related = await issueId('E2E related issue');
const closed = await issueId('E2E closed issue');
await t.go(`/issues/${related}`);
if (!(await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count())) t.problems.push('no sidebar block');
if (!(await entry().locator('a.icon-add').count())) t.problems.push('no add button for E2E cleanup');
await t.shot('manager', 'The sidebar lists the project\'s to-do lists with an add button on each list that does not hold the issue');
await entry().locator('a.icon-add').click();
await t.settle();
t.check('add');
if (!(await entry().locator('a.icon-link-break').count())) t.problems.push('add: no remove button afterwards');
await t.shot('added', 'After the add the issue page shows the remove button for E2E cleanup');

await t.login('viewer');
await t.go(`/issues/${related}`);
if (await t.page.locator('#sidebar a.icon-add, #sidebar a.icon-link-break').count()) t.problems.push('viewer sees buttons');
if (!(await entry().locator('.icon-checked').count())) t.problems.push('viewer: no listed mark');
await t.shot('viewer', 'A view-only member sees the lists and a check mark where the issue is listed, no buttons');

await t.login('reporter');
await t.go(`/issues/${related}`);
if (await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count()) t.problems.push('reporter sees the block');
await t.shot('reporter', 'A member without the plugin\'s permissions sees no to-do list block');

await t.login('manager');
await t.go(`/issues/${related}`);
t.page.once('dialog', d => d.accept());
await entry().locator('a.icon-link-break').click();
await t.settle();
t.check('remove');
if (!/\/issues\/\d+$/.test(t.page.url())) t.problems.push(`remove: back on ${t.page.url()}`);
if (!(await entry().locator('a.icon-add').count())) t.problems.push('remove: no add button afterwards');
await t.shot('removed', 'After confirming the remove, the issue page is shown again with the add button');

await t.go(`/issues/${closed}`);
if (await entry().locator('a.icon-add').count()) t.problems.push('closed issue: add offered on a list that removes closed issues');
await t.shot('closed-issue', 'A closed issue gets no add button for E2E cleanup, which removes closed issues');

await t.done();
