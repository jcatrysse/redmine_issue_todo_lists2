// CSV export of a list and the REST API (index and show, JSON and XML) with
// API keys: allowed for members who may view lists, refused to the others.
// The responses are written to docs/e2e/csv_api-results.txt as evidence.
import fs from 'node:fs';
import path from 'node:path';
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('csv_api');
const out = [];
const note = (line) => out.push(line);

async function apiKey(user) {
  await t.login(user);
  await t.go('/my/api_key');
  await t.sudo();
  return (await t.page.locator('#content .box pre').innerText()).trim();
}
// who: a seeded user (with that user's key), 'bogus' (a wrong key) or null (no key)
async function api(who, url, expected) {
  const key = who === 'bogus' ? 'not-a-key' : who && keys[who];
  const headers = key ? { 'X-Redmine-API-Key': key } : {};
  const r = await t.page.request.get(`${t.BASE}${url}`, { headers, maxRedirects: 0 });
  note(`GET ${url} ${who ? `with the API key of ${who}` : 'without a key'} -> HTTP ${r.status()}`);
  if (r.status() !== expected) t.problems.push(`${url}: HTTP ${r.status()}, expected ${expected}`);
  return r;
}

const keys = {};
for (const user of ['manager', 'viewer', 'reporter', 'outsider']) keys[user] = await apiKey(user);

await t.login('manager');
await t.go(`/projects/${P}/issue_todo_lists`);
const sprintPath = await t.page.locator('table.list a:text-is("E2E sprint")').getAttribute('href');
await t.go(sprintPath);
await t.shot('csv-link', 'The list page offers the CSV export at the bottom');
const csv = await t.page.request.get(`${t.BASE}${sprintPath}.csv`);
const body = await csv.body();
const text = body.toString('utf8');
note(`GET ${sprintPath}.csv as manager -> HTTP ${csv.status()}, ${csv.headers()['content-type']}`);
note(text.replace(/^﻿/, '[BOM]'));
if (csv.status() !== 200) t.problems.push(`csv: HTTP ${csv.status()}`);
if (!text.startsWith('﻿')) t.problems.push('csv: no UTF-8 BOM');
if (!/Order/.test(text.split('\n')[0]) || !/E2E assigned issue/.test(text) || !/order the coffee/.test(text)) t.problems.push('csv: header or rows missing');

await t.login('reporter');
const refused = await t.page.request.get(`${t.BASE}${sprintPath}.csv`);
note(`GET ${sprintPath}.csv as reporter -> HTTP ${refused.status()}`);
if (refused.status() !== 403) t.problems.push(`csv as reporter: HTTP ${refused.status()}, expected 403`);

// REST API
const sprintId = sprintPath.match(/(\d+)$/)[1];
const index = await api('manager', `/projects/${P}/issue_todo_lists.json`, 200);
const lists = (await index.json()).todo_lists || [];
note(`  ${lists.length} lists: ${lists.map(l => l.title).join(', ')}`);
if (!lists.some(l => l.title === 'E2E sprint')) t.problems.push('api index: E2E sprint missing');
const show = await api('viewer', `/projects/${P}/issue_todo_lists/${sprintId}.json`, 200);
const items = (await show.json()).todo_list_items || [];
note(`  ${items.length} items: ${items.map(i => (i.issue ? `#${i.issue.id} ${i.issue.subject}` : `text "${i.comment}"`)).join('; ')}`);
if (!items.some(i => i.issue) || !items.some(i => !i.issue)) t.problems.push('api show: issue or text item missing');
const xml = await api('manager', `/projects/${P}/issue_todo_lists/${sprintId}.xml`, 200);
const xmlText = await xml.text();
note(`  XML starts: ${xmlText.slice(0, 120).replace(/\n/g, ' ')}`);
if (!/<todo_list_items type="array">/.test(xmlText)) t.problems.push('api xml: no todo_list_items array');
await api('reporter', `/projects/${P}/issue_todo_lists.json`, 403);
await api('outsider', '/projects/e2e-private/issue_todo_lists.json', 403);
await api('manager', '/projects/e2e-private/issue_todo_lists.json', 200);
await api(null, '/projects/e2e-private/issue_todo_lists.json', 401);
await api('bogus', `/projects/${P}/issue_todo_lists.json`, 401);
// Only index and show take API keys; a write with a key is not accepted.
const post = await t.page.request.post(`${t.BASE}/projects/${P}/issue_todo_lists.json`, {
  headers: { 'X-Redmine-API-Key': keys.manager, 'Content-Type': 'application/json' },
  data: { issue_todo_list: { title: 'Created through the API' } },
});
note(`POST /projects/${P}/issue_todo_lists.json with the API key of manager -> HTTP ${post.status()}`);
if (post.status() < 400) t.problems.push(`api create: HTTP ${post.status()}, expected a refusal`);

fs.writeFileSync(path.join(process.env.RMP_E2E_OUT || 'docs/e2e', 'csv_api-results.txt'), out.join('\n') + '\n');
await t.done();
