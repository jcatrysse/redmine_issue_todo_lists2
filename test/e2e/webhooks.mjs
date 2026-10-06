// Redmine 7 webhooks with the plugin: a webhook on e2e-project receives the
// issue events when the issue form changes the lists and when closing takes
// an issue off a list that removes closed issues. The payload is core's issue
// API (issues/show.api.rsb), which shows no to-do lists, like the REST API.
// Webhooks refuse loopback addresses, so the listener binds to the host's
// own address (RMP_WEBHOOK_HOST, default: the first non-internal IPv4).
import http from 'node:http';
import os from 'node:os';
import fs from 'node:fs';
import path from 'node:path';
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('webhooks');
const host = process.env.RMP_WEBHOOK_HOST ||
  Object.values(os.networkInterfaces()).flat().find(i => i && i.family === 'IPv4' && !i.internal)?.address;
if (!host) throw new Error('no non-loopback IPv4 address for the webhook listener');

const received = [];
const server = http.createServer((req, res) => {
  let body = '';
  req.on('data', c => { body += c; });
  req.on('end', () => { try { received.push(JSON.parse(body)); } catch { received.push({ raw: body }); } res.end('ok'); });
});
await new Promise(r => server.listen(0, '0.0.0.0', r));
const url = `http://${host}:${server.address().port}/hook`;
async function waitFor(pred, what) {
  for (let i = 0; i < 40; i++) {
    const hit = received.find(pred);
    if (hit) return hit;
    await new Promise(r => setTimeout(r, 500));
  }
  t.problems.push(`no webhook payload for ${what} (got ${received.map(p => p.type).join(', ') || 'nothing'})`);
  return null;
}
async function listedOn(title) {
  await t.go(`/projects/${P}/issue_todo_lists`);
  await t.page.click(`table.list a:text-is("${title}")`);
  await t.settle();
  return t.page.locator('#issue-todo-list-table td.id a').allInnerTexts();
}

await t.login('admin');
await t.go('/settings?tab=integrations');
await t.sudo();
await t.go('/settings?tab=integrations');
await t.page.check('#settings_webhooks_enabled');
await t.page.click('#tab-content-integrations input[name=commit]');
await t.settle();
await t.sudo();
t.check('enable webhooks');

await t.login('manager');
await t.go('/webhooks/new');
await t.sudo();
await t.page.fill('#webhook_url', url);
await t.page.check('#webhook_active');
for (const event of ['issue.updated', 'issue.closed']) await t.page.check(`#webhook_events_${event.replace('.', '\\.')}`);
await t.page.locator('#webhook_project_ids label', { hasText: 'E2E project' }).locator('input').check();
await t.shot('new-webhook', 'The manager adds a webhook for issue updates and closes on E2E project, pointing at the scenario\'s listener');
await t.page.click('#content input[name=commit]');
await t.settle();
await t.sudo();
t.check('create webhook');

// Edit an issue: add it to E2E cleanup through the form, with a note.
await t.go(`/projects/${P}/issues/new`);
const subject = `E2E webhook issue ${Date.now()}`;
await t.page.fill('#issue_subject', subject);
await t.page.click('#issue-form input[name=commit]');
await t.settle();
const id = t.page.url().match(/\/issues\/(\d+)/)[1];
await t.go(`/issues/${id}/edit`);
const cleanup = await t.page.locator('#issue_issue_todo_list_ids option', { hasText: 'E2E cleanup' }).getAttribute('value');
await t.page.selectOption('#issue_issue_todo_list_ids', [cleanup]);
await t.page.fill('#issue_notes', 'Put on E2E cleanup, with a webhook listening.');
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('edit issue');
const updated = await waitFor(p => p.type === 'issue.updated' && p.data?.issue?.id === Number(id), 'issue.updated');
if (!(await listedOn('E2E cleanup')).includes(id)) t.problems.push('form: issue not added to E2E cleanup');

// Close it as administrator (the seeded role has no workflow).
await t.login('admin');
await t.go(`/issues/${id}/edit`);
await t.page.selectOption('#issue_status_id', await t.page.locator('#issue_status_id option', { hasText: /^Closed$/ }).getAttribute('value'));
await t.settle();
await t.page.click('#issue-form input[name=commit]');
await t.settle();
t.check('close issue');
const closed = await waitFor(p => p.type === 'issue.closed' && p.data?.issue?.id === Number(id), 'issue.closed');
if (closed && !closed.data.issue.closed_on) t.problems.push('issue.closed payload has no closed_on');
await t.login('manager');
if ((await listedOn('E2E cleanup')).includes(id)) t.problems.push('close: issue still on E2E cleanup');

// Show what arrived, as evidence, and remove the webhook so a rerun starts clean.
const summary = received.map(p => ({ type: p.type, issue: p.data?.issue && { id: p.data.issue.id, status: p.data.issue.status?.name, keys: Object.keys(p.data.issue) } }));
fs.writeFileSync(path.join(process.env.RMP_E2E_OUT || 'docs/e2e', 'webhooks-payloads.json'), JSON.stringify(summary, null, 2) + '\n');
for (const p of [updated, closed].filter(Boolean)) {
  if (Object.keys(p.data.issue).some(k => /todo/i.test(k))) t.problems.push(`${p.type}: payload carries to-do list data`);
}
await t.page.setContent(`<pre style="font: 13px monospace; white-space: pre-wrap">${JSON.stringify(summary, null, 2).replace(/</g, '&lt;')}</pre>`);
await t.shot('payloads', 'What the listener received: issue.updated after the form put the issue on E2E cleanup, issue.closed after closing (it left the list); no to-do list fields, like the issue API');
await t.go('/webhooks');
t.page.once('dialog', d => d.accept());
await t.page.locator('tr', { hasText: url }).locator('a.icon-del').click();
await t.settle();
await t.sudo();
t.check('delete webhook');
if (await t.page.locator('tr', { hasText: url }).count()) t.problems.push('webhook not deleted');
await t.shot('webhook-deleted', 'The scenario\'s webhook is deleted again');

server.close();
await t.done();
