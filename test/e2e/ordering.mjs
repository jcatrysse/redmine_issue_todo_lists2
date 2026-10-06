// Ordering the items of a list by drag and drop (jQuery UI sortable): the new
// order is stored and survives a reload; without the permission the rows do
// not move and a posted order is refused.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('ordering');
const rows = () => t.page.locator('#issue-todo-list-table > tbody > tr');
const ids = async () => (await rows().evaluateAll(trs => trs.map(tr => tr.id)));

await t.login('manager');
await t.go(`/projects/${P}/issue_todo_lists`);
await t.page.click('table.list a:text-is("E2E sprint")');
await t.settle();
const listPath = new URL(t.page.url()).pathname;
if ((await rows().count()) < 3) t.problems.push('E2E sprint needs three items');
const before = await ids();
await t.shot('before', 'E2E sprint before ordering; the table is sortable for a member with the permission');

// Drag the last row above the first, in small steps as a user would.
const from = await rows().last().locator('td.issue-todo-list-item-order').boundingBox();
const to = await rows().first().boundingBox();
await t.page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
await t.page.mouse.down();
for (let i = 1; i <= 15; i++) {
  await t.page.mouse.move(from.x + from.width / 2, from.y + from.height / 2 - ((from.y - to.y + 5) * i) / 15);
}
const saved = t.page.waitForResponse(r => r.url().endsWith('/update_item_order'));
await t.page.mouse.up();
const res = await saved;
if (res.status() !== 200) t.problems.push(`update_item_order: HTTP ${res.status()}`);
await t.settle();
t.check('drag');
const after = await ids();
const expected = [before[before.length - 1], ...before.slice(0, -1)];
if (after.join() !== expected.join()) t.problems.push(`drag: order ${after} instead of ${expected}`);
await t.shot('dragged', 'The last item is dragged to the top; the order numbers follow and the change is posted');

await t.go(listPath);
if ((await ids()).join() !== expected.join()) t.problems.push('reload: the new order was not stored');
const order = await t.page.locator('#issue-todo-list-table td.issue-todo-list-item-order').allInnerTexts();
if (order.map(s => s.trim()).join(',') !== '1,2,3') t.problems.push(`reload: order numbers ${order}`);
await t.shot('reloaded', 'After a reload the new order is still there, numbered 1 to 3');

// Put the seed order back, so the run can be repeated.
const token = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
const restore = await t.page.request.post(`${t.BASE}${listPath}/update_item_order`, {
  headers: { 'X-CSRF-Token': token, 'X-Requested-With': 'XMLHttpRequest', Accept: 'text/javascript', 'Content-Type': 'application/x-www-form-urlencoded' },
  data: before.map(id => `item[]=${id.replace(/\D/g, '')}`).join('&'),
});
if (restore.status() !== 200) t.problems.push(`restore order: HTTP ${restore.status()}`);
await t.go(listPath);
if ((await ids()).join() !== before.join()) t.problems.push('restore: the seed order was not put back');

await t.login('viewer');
await t.go(listPath);
if (await t.page.locator('#issue-todo-list-table.sortable').count()) t.problems.push('viewer: table is sortable');
const vfrom = await rows().last().boundingBox();
await t.page.mouse.move(vfrom.x + 60, vfrom.y + vfrom.height / 2);
await t.page.mouse.down();
await t.page.mouse.move(vfrom.x + 60, vfrom.y - 80, { steps: 10 });
await t.page.mouse.up();
await t.settle();
if ((await ids()).join() !== before.join()) t.problems.push('viewer: the rows moved');
await t.shot('viewer-not-sortable', 'A view-only member drags in vain: the table is not sortable and the order stays');
const vtoken = await t.page.locator('meta[name=csrf-token]').getAttribute('content');
const refused = await t.page.request.post(`${t.BASE}${listPath}/update_item_order`, {
  headers: { 'X-CSRF-Token': vtoken, 'X-Requested-With': 'XMLHttpRequest', Accept: 'text/javascript', 'Content-Type': 'application/x-www-form-urlencoded' },
  data: [...before].reverse().map(id => `item[]=${id.replace(/\D/g, '')}`).join('&'),
});
if (refused.status() !== 403) t.problems.push(`viewer POST order: HTTP ${refused.status()}, expected 403`);
await t.go(listPath);
if ((await ids()).join() !== before.join()) t.problems.push('viewer POST changed the order');

await t.done();
