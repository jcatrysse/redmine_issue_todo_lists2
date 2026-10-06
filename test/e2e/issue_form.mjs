// The "To-do lists" field of the issue form: add an issue to a list on
// creation, add and remove it when editing, keep the choice when the form
// comes back with an error; no field for a member without the permissions.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('issue_form');
const field = '#issue_issue_todo_list_ids';
const optionValue = async title => t.page.locator(`${field} option`, { hasText: title }).getAttribute('value');
async function listed(title) {
  await t.go(`/projects/${P}/issue_todo_lists`);
  await t.page.click(`table.list a:text-is("${title}")`);
  await t.settle();
  return t.page.locator('#issue-todo-list-table td.id a').allInnerTexts();
}

await t.login('manager');
await t.go(`/projects/${P}/issues/new`);
const subject = `E2E issue for a list ${Date.now()}`;
await t.page.fill('#issue_subject', subject);
await t.page.selectOption(field, [await optionValue('E2E cleanup')]);
await t.shot('new-form', 'The new issue form offers the project\'s to-do lists; E2E cleanup is chosen');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('create');
const id = (t.page.url().match(/\/issues\/(\d+)/) || [])[1];
if (!id) t.problems.push(`create: still on ${t.page.url()}`);
if (!(await listed('E2E cleanup')).includes(id)) t.problems.push('create: new issue not on E2E cleanup');
await t.shot('new-listed', 'The new issue is on E2E cleanup');

// Edit: add to E2E sprint, take off E2E cleanup.
await t.go(`/issues/${id}/edit`);
await t.page.selectOption(field, [await optionValue('E2E sprint')]);
await t.shot('edit-form', 'Editing: E2E sprint chosen, E2E cleanup no longer');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('edit');
if (!(await listed('E2E sprint')).includes(id)) t.problems.push('edit: not added to E2E sprint');
if ((await listed('E2E cleanup')).includes(id)) t.problems.push('edit: not removed from E2E cleanup');
await t.go(`/issues/${id}`);
await t.shot('edited', 'The sidebar shows the issue on E2E sprint (remove button) and not on E2E cleanup (add button)');

// A validation error keeps the choice.
await t.go(`/issues/${id}/edit`);
await t.page.selectOption(field, [await optionValue('E2E cleanup'), await optionValue('E2E sprint')]);
await t.page.fill('#issue_subject', '');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('invalid');
const kept = await t.page.locator(`${field} option:checked`).allInnerTexts();
if (!(await t.page.locator('#errorExplanation').count())) t.problems.push('invalid: no error');
if (kept.length !== 2) t.problems.push(`invalid: chosen lists ${kept}`);
await t.shot('invalid-kept', 'A blank subject is refused; the form keeps both chosen lists');
if ((await listed('E2E cleanup')).includes(id)) t.problems.push('invalid: the refused form changed the lists');

await t.login('reporter');
await t.go(`/projects/${P}/issues/new`);
if (await t.page.locator(field).count()) t.problems.push('reporter sees the field');
await t.shot('reporter-no-field', 'A member without the plugin\'s permissions gets the issue form without the to-do list field');

await t.done();
