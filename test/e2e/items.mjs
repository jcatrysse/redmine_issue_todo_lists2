// Items on a list: adding an issue by number (with and without #), a text
// item, editing a comment and the fields of a text item, removing an item,
// and the refusals: an unknown issue, an empty item, a closed issue on a list
// that removes closed issues.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('items');

async function issueId(subject) {
  const r = await t.page.request.get(`${t.BASE}/issues.json?project_id=${P}&status_id=*&subject=${encodeURIComponent(subject)}`);
  const issue = (await r.json()).issues.find(i => i.subject === subject);
  if (!issue) throw new Error(`no issue "${subject}"`);
  return issue.id;
}
async function addItem(issue, comment) {
  await t.page.fill('#item_issue_id', issue);
  await t.page.fill('#new_item_comment', comment);
  await t.page.click('#new-item-form input[type=submit]');
  await t.page.waitForResponse(r => r.url().includes('/items') && r.request().method() === 'POST');
  await t.settle();
}
const rows = () => t.page.locator('#issue-todo-list-table > tbody > tr');

await t.login('manager');
const subtask = await issueId('E2E subtask');
const related = await issueId('E2E related issue');
const closed = await issueId('E2E closed issue');

// A list of its own, which also shows two fields for text items. A text
// item's value is shown in the issue column of the same name, so due date is
// added to the issue columns as well.
const title = `E2E items ${Date.now()}`;
await t.go(`/projects/${P}/issue_todo_lists/new`);
await t.page.fill('#issue_todo_list_title', title);
await t.page.check('input[name="issue_todo_list[included_columns][]"][value="due_date"]');
for (const field of ['due_date', 'assigned_to']) {
  await t.page.check(`input[name="issue_todo_list[included_fields][]"][value="${field}"]`);
}
await t.page.click('#content input[name=commit]');
await t.settle();
t.check('create list');
const listPath = new URL(t.page.url()).pathname;

await addItem(String(subtask), 'First, *formatted*');
await addItem(`#${related}`, '');
await addItem('', 'A text item without an issue');
t.check('add items');
if ((await rows().count()) !== 3) t.problems.push(`add: ${await rows().count()} rows instead of 3`);
await t.shot('added', 'An issue by number, one with #, and a text item are added without reloading; the comment is formatted');

await addItem('999999', '');
t.check('unknown issue');
if (!(await t.page.locator('#new-item-form .errors #errorExplanation').count())) t.problems.push('unknown issue: no error');
if ((await rows().count()) !== 3) t.problems.push('unknown issue: a row was added');
await t.shot('unknown-issue-refused', 'An unknown issue number is refused with an error, nothing is added', { full: false });

await addItem('', '');
t.check('empty item');
if (!(await t.page.locator('#new-item-form .errors', { hasText: /./ }).count())) t.problems.push('empty item: no error');
await t.shot('empty-item-refused', 'An item without issue and without comment is refused', { full: false });

// Edit the comment of the first item, then the fields of the text item.
await t.page.click('#issue-todo-list-table tr >> nth=1 >> a.edit_item');
await t.page.waitForSelector('#edit_item_comment');
await t.page.fill('#edit_item_comment', 'Comment changed in the e2e run');
await t.shot('edit-comment-form', 'The edit form opens under the list with the current comment');
await t.page.click('#edit-item-form input[type=submit]');
await t.page.waitForResponse(r => /\/items\/\d+/.test(r.url()) && r.request().method() !== 'GET');
await t.settle();
t.check('edit comment');
if (!(await rows().first().locator('.wiki', { hasText: 'Comment changed in the e2e run' }).count())) t.problems.push('edit: comment not shown');

await t.page.click('#issue-todo-list-table tr >> nth=3 >> a.edit_item');
await t.page.waitForSelector('#edit-item-form input[type=date]');
await t.page.fill('#edit-item-form input[type=date]', '2026-12-24');
await t.page.fill('#edit-item-form input[type=text]', 'Somebody outside Redmine');
await t.shot('edit-text-item-form', 'A text item offers the fields the list includes: a date field for the due date, text for the assignee');
await t.page.click('#edit-item-form input[type=submit]');
await t.page.waitForResponse(r => /\/items\/\d+/.test(r.url()) && r.request().method() !== 'GET');
await t.settle();
t.check('edit text item');
const textRow = rows().nth(2);
if (!(await textRow.getByText('2026-12-24').count()) || !(await textRow.getByText('Somebody outside Redmine').count())) {
  t.problems.push('edit text item: values not shown');
}
await t.shot('edited', 'The changed comment and the text item\'s values are shown in the list');

// Remove the second item: the order numbers stay 1..n.
t.page.once('dialog', d => d.accept());
await t.page.click('#issue-todo-list-table tr >> nth=2 >> a.icon-link-break');
await t.page.waitForResponse(r => /\/items\/\d+/.test(r.url()) && r.request().method() !== 'GET');
await t.settle();
t.check('remove');
const order = await t.page.locator('#issue-todo-list-table td.issue-todo-list-item-order').allInnerTexts();
if (order.map(s => s.trim()).join(',') !== '1,2') t.problems.push(`remove: order is ${order}`);
await t.shot('removed', 'After confirming, the item is removed and the order numbers stay contiguous');

// A list that removes closed issues refuses a closed one.
await t.go(`/projects/${P}/issue_todo_lists`);
await t.page.click('table.list a:text-is("E2E cleanup")');
await t.settle();
await addItem(String(closed), '');
t.check('closed issue');
if (!(await t.page.locator('#new-item-form .errors', { hasText: /./ }).count())) t.problems.push('closed issue: no error');
await t.shot('closed-issue-refused', 'A list that removes closed issues refuses a closed issue with an error', { full: false });

// The item actions are refused without the permissions.
await t.login('viewer');
await t.go(listPath);
if (await t.page.locator('a.edit_item, a.icon-link-break, #new-item-form').count()) t.problems.push('viewer sees item tools');
await t.shot('viewer', 'A view-only member sees the items, without add, edit or remove');
const token = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
const post = await t.page.request.post(`${t.BASE}${listPath}/items`, {
  headers: { 'X-CSRF-Token': token, 'X-Requested-With': 'XMLHttpRequest', Accept: 'text/javascript' },
  form: { 'item[issue_id]': String(subtask) },
});
if (post.status() !== 403) t.problems.push(`viewer POST item: HTTP ${post.status()}, expected 403`);

await t.done();
