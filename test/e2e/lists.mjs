// To-do lists: the project menu entry, the index, creating (also with a blank
// title), editing and deleting a list, and the refusals for users without the
// permissions or the membership.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('lists');
const title = `E2E list ${Date.now()}`;

await t.login('manager');
await t.go(`/projects/${P}`);
await t.page.click('#main-menu a.issue-todo-lists');
await t.settle();
t.check('menu');
if (!(await t.page.locator('table.list a', { hasText: 'E2E sprint' }).count())) t.problems.push('index: E2E sprint not listed');
await t.shot('index', 'The project menu entry leads to the index of the project\'s lists, with the New link');

await t.page.click('a.icon-add');
await t.settle();
await t.page.click('#content input[name=commit]');
await t.settle();
t.check('create blank');
if (!(await t.page.locator('#errorExplanation').count())) t.problems.push('create with a blank title: no error shown');
await t.shot('create-blank-title', 'A blank title is refused with a validation error, the form stays');

await t.page.fill('#issue_todo_list_title', title);
await t.page.fill('#issue_todo_list_description', 'Created by the *e2e* scenario.');
await t.page.check('#issue_todo_list_remove_closed_issues');
await t.shot('create-form', 'The form with title, description, remove closed issues and the column choice');
await t.page.click('#content input[name=commit]');
await t.settle();
t.check('create');
if (!/\/issue_todo_lists\/\d+$/.test(t.page.url())) t.problems.push(`create: still on ${t.page.url()}`);
if (!(await t.page.locator('#flash_notice').count())) t.problems.push('create: no notice');
await t.shot('created', 'The new list is shown with its formatted description and a notice');
const listPath = new URL(t.page.url()).pathname;

await t.page.click('#content .contextual a.icon-edit');
await t.settle();
await t.page.fill('#issue_todo_list_title', `${title} renamed`);
await t.page.click('#content input[name=commit]');
await t.settle();
t.check('edit');
if (!(await t.page.locator('h2', { hasText: `${title} renamed` }).count())) t.problems.push('edit: new title not shown');
await t.shot('edited', 'Editing the list stores the new title');

await t.login('viewer');
await t.go(`/projects/${P}/issue_todo_lists`);
if (await t.page.locator('#content a.icon-add').count()) t.problems.push('viewer sees the New link');
await t.shot('index-viewer', 'A member who may only view lists sees the index without the New link');
await t.go(listPath);
if (await t.page.locator('#content .contextual a').count()) t.problems.push('viewer sees edit or delete');
await t.shot('show-viewer', 'The same member sees the list without edit, delete, add or ordering tools');
await t.go(`/projects/${P}/issue_todo_lists/new`, { status: 403 });
await t.shot('new-viewer-refused', 'Creating a list without the permission is refused (403)');
await t.go(`${listPath}/edit`, { status: 403 });

await t.login('reporter');
await t.go(`/projects/${P}`);
if (await t.page.locator('#main-menu a.issue-todo-lists').count()) t.problems.push('reporter sees the menu entry');
await t.go(`/projects/${P}/issue_todo_lists`, { status: 403 });
await t.shot('index-reporter-refused', 'A member without the plugin\'s permissions has no menu entry and is refused (403)');

await t.login('outsider');
await t.go('/projects/e2e-private/issue_todo_lists', { status: 403 });
await t.shot('private-outsider-refused', 'The lists of a private project are refused to a non-member (403)');
await t.go(`/projects/${P}/issue_todo_lists`, { status: 403 });

await t.anonymous();
await t.go('/projects/e2e-private/issue_todo_lists/3');
if (!/\/login/.test(t.page.url())) t.problems.push(`anonymous on a private list: not sent to login (${t.page.url()})`);
await t.shot('private-anonymous-login', 'Anonymous on a private project\'s list is sent to the login page');

await t.login('manager');
await t.go(listPath);
t.page.once('dialog', d => d.accept());
await t.page.click('#content .contextual a.icon-del');
await t.settle();
t.check('delete');
if (await t.page.locator('table.list a', { hasText: title }).count()) t.problems.push('delete: list still in the index');
if (!(await t.page.locator('#flash_notice').count())) t.problems.push('delete: no notice');
await t.shot('deleted', 'After confirming, the list is deleted and the index shows a notice');
await t.go(listPath, { status: 404 });

await t.done();
