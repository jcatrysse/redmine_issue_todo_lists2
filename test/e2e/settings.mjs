// The plugin settings: with "show in issue sidebar" and "show in issue edit"
// off, the issue page and form show nothing of the plugin; only an
// administrator reaches the settings page.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('settings');
const url = '/settings/plugin/redmine_issue_todo_lists2';

async function save(on) {
  await t.go(url);
  await t.sudo();
  for (const key of ['show_in_issue_sidebar', 'show_in_issue_edit']) {
    const box = t.page.locator(`#settings_${key}`);
    if (on) await box.check(); else await box.uncheck();
  }
  await t.page.click('#content input[name=commit]');
  await t.settle();
  await t.sudo();
  t.check(`save ${on}`);
  if (!(await t.page.locator('#flash_notice').count())) t.problems.push(`save ${on}: no notice`);
}

await t.login('admin');
await t.go(url);
await t.sudo();
await t.shot('page', 'The plugin settings page with both options on (the defaults)');
await save(false);
await t.shot('off', 'Both options switched off and saved');

await t.login('manager');
await t.go('/issues/1');
if (await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count()) t.problems.push('off: sidebar block still shown');
await t.shot('issue-off', 'With the sidebar option off, the issue page shows no to-do list block');
await t.go('/issues/1/edit');
if (await t.page.locator('#issue_issue_todo_list_ids').count()) t.problems.push('off: form field still shown');
await t.shot('edit-off', 'With the edit option off, the issue form has no to-do list field');
await t.go(url, { status: 403 });
await t.shot('manager-refused', 'The settings page is refused to a non-administrator (403)');

await t.login('admin');
await save(true);
await t.login('manager');
await t.go('/issues/1');
if (!(await t.page.locator('#sidebar h3', { hasText: 'To-do lists' }).count())) t.problems.push('on: sidebar block missing');
await t.go('/issues/1/edit');
if (!(await t.page.locator('#issue_issue_todo_list_ids').count())) t.problems.push('on: form field missing');
await t.shot('edit-on', 'Switched on again, the issue form shows the to-do list field');

await t.done();
