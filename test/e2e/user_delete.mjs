// Deleting a user who created and last changed a list: the administrator can
// delete the account, the list stays and names Anonymous instead.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('user_delete');
const login = `leaver${Date.now()}`;
const password = 'Redmine7Test!';

await t.login('admin');
await t.go('/users/new');
await t.sudo();
await t.page.fill('#user_login', login);
await t.page.fill('#user_firstname', 'Leaving');
await t.page.fill('#user_lastname', 'User');
await t.page.fill('#user_mail', `${login}@example.net`);
await t.page.fill('#user_password', password);
await t.page.fill('#user_password_confirmation', password);
if (await t.page.locator('#user_must_change_passwd').isChecked()) await t.page.uncheck('#user_must_change_passwd');
await t.page.click('#content input[name=commit]');
await t.settle();
await t.sudo();
t.check('create user');
const userId = (t.page.url().match(/\/users\/(\d+)/) || [])[1];
if (!userId) throw new Error(`user not created: ${t.page.url()}`);
await t.go(`/users/${userId}/memberships/new`);
await t.page.locator('.projects-selection label', { hasText: 'E2E project' }).locator('input').check();
await t.page.locator('.roles-selection label', { hasText: 'E2E full' }).locator('input').check();
await t.page.click('#content input[type=submit]');
await t.settle();
t.check('membership');

await t.login(login, password);
const title = `E2E list of ${login}`;
await t.go(`/projects/${P}/issue_todo_lists/new`);
await t.page.fill('#issue_todo_list_title', title);
await t.page.click('#content input[name=commit]');
await t.settle();
const listPath = new URL(t.page.url()).pathname;
await t.shot('created-by-leaver', 'A list created by the user who will be deleted');

await t.login('admin');
await t.go(`/users/${userId}/edit`);
await t.sudo();
t.page.once('dialog', d => d.accept());
await t.page.click('#content .contextual a.icon-del');
await t.settle();
await t.sudo();
await t.page.fill('#confirm', login);
await t.shot('confirm-delete', 'The administrator confirms the deletion of the account');
await t.page.click('#content input[type=submit][name=commit]');
await t.settle();
t.check('delete user');
if (!(await t.page.locator('#flash_notice').count())) t.problems.push('delete user: no notice (refused by the foreign key?)');
await t.shot('deleted', 'The account is deleted without an error');

await t.login('manager');
await t.go(listPath);
const box = await t.page.locator('#show-right-box').innerText();
if (!/Anonymous/.test(box) || box.includes('Leaving')) t.problems.push(`list after delete: "${box}"`);
await t.shot('list-after', 'The list is still there and names Anonymous as creator and last editor');

await t.done();
