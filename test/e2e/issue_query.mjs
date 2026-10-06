// The issue list: the "To-do lists" filter (is, none), the columns with the
// list titles (links) and the order numbers, and sorting on the order. Not
// offered to a member who may not view lists.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('issue_query');
const columns = 'c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions';

await t.login('manager');
await t.go(`/projects/${P}/issue_todo_lists`);
const sprintId = (await t.page.locator('table.list a:text-is("E2E sprint")').getAttribute('href')).match(/(\d+)$/)[1];
await t.go(`/projects/${P}/issue_todo_lists/${sprintId}`);
const onSprint = (await t.page.locator('#issue-todo-list-table td.id a').allInnerTexts()).map(s => s.trim());

await t.go(`/projects/${P}/issues?set_filter=1&f[]=&${columns}`);
await t.page.selectOption('#add_filter_select', 'todo_lists_ids');
await t.page.selectOption('#values_todo_lists_ids_1', sprintId);
await t.shot('filter-form', 'The To-do lists filter is offered in the issue list and set to E2E sprint');
await t.page.click('#query_form_with_buttons a.icon-checked, #query_form a.icon-checked');
await t.settle();
t.check('apply filter');
const shown = (await t.page.locator('table.issues td.id a').allInnerTexts()).map(s => s.trim());
if (shown.sort().join() !== [...onSprint].sort().join()) t.problems.push(`filter is: shows ${shown}, list holds ${onSprint}`);
const titles = t.page.locator('table.issues td.issue_todo_list_titles-titles a', { hasText: 'E2E sprint' });
if (!(await titles.count())) t.problems.push('titles column: no link to E2E sprint');
await t.shot('filtered', 'Filtered on E2E sprint: exactly the issues on that list, with the list titles as links and the order numbers');

await t.go(`/projects/${P}/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=!*&f[]=status_id&op[status_id]=*&${columns}`);
const none = (await t.page.locator('table.issues td.id a').allInnerTexts()).map(s => s.trim());
if (none.some(id => onSprint.includes(id))) t.problems.push('filter none: shows an issue that is on a list');
await t.shot('filter-none', 'The operator "none" shows the issues that are on no list');

await t.go(`/projects/${P}/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]==&v[todo_lists_ids][]=${sprintId}&${columns}&sort=issue_todo_list_item_orders.positions`);
// The README: sorting uses the lowest position of each issue over all lists.
const mins = await t.page.locator('table.issues td.issue_todo_list_item_orders-positions').evaluateAll(tds =>
  tds.map(td => Math.min(...(td.textContent.match(/\d+/g) || ['Infinity']).map(Number))));
if (!mins.length || mins.some((m, i) => i && m < mins[i - 1])) t.problems.push(`sort on order: lowest positions ${mins} not ascending`);
await t.shot('sorted', 'Sorted on the order column: by the lowest position each issue has on any list (README)');

await t.login('reporter');
await t.go(`/projects/${P}/issues`);
const options = await t.page.locator('#add_filter_select option').evaluateAll(os => os.map(o => o.value));
if (options.includes('todo_lists_ids')) t.problems.push('reporter is offered the filter');
await t.go(`/projects/${P}/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]==&v[todo_lists_ids][]=${sprintId}&${columns}`);
if (await t.page.locator('table.issues td.issue_todo_list_titles-titles').count()) t.problems.push('reporter gets the titles column');
await t.shot('reporter', 'A member who may not view lists gets neither the filter nor the columns, even from a URL');

await t.done();
