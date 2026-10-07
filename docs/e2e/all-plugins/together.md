# together

Run 2026-10-07T16:47:05.787Z against http://127.0.0.1:3003.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](together-admin-project-settings.png) | admin | `/projects/e2e-project/settings` | Project > Settings answers 200 for admin |
| ![](together-admin-issue-list.png) | admin | `/projects/e2e-project/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=*&f[]=status_id&op[status_id]=*&c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions` | The issue list filtered on "any to-do list", with the titles and order columns, sorted on the order, as admin |
| ![](together-admin-issue.png) | admin | `/issues/1` | An issue page with the to-do list block, as admin |
| ![](together-manager-project-settings.png) | manager | `/projects/e2e-project/settings` | Project > Settings answers 200 for manager |
| ![](together-manager-issue-list.png) | manager | `/projects/e2e-project/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=*&f[]=status_id&op[status_id]=*&c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions` | The issue list filtered on "any to-do list", with the titles and order columns, sorted on the order, as manager |
| ![](together-manager-issue.png) | manager | `/issues/1` | An issue page with the to-do list block, as manager |
| ![](together-reporter-project-settings-refused.png) | reporter | `/projects/e2e-project/settings` | Project > Settings is refused to a member without the permission (403) |
| ![](together-reporter-issue-list.png) | reporter | `/projects/e2e-project/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=*&f[]=status_id&op[status_id]=*&c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions` | The same issue list URL works for a member without the plugin's permissions, without the filter and columns |
| ![](together-reporter-issue.png) | reporter | `/issues/1` | The issue page answers 200 without the to-do list block |
| ![](together-outsider-private-refused.png) | outsider | `/projects/e2e-private/issues` | The private project's issue list is refused to a non-member (403) |
| ![](together-outsider-issue-list.png) | outsider | `/projects/e2e-project/issues?set_filter=1&f[]=todo_lists_ids&op[todo_lists_ids]=*&f[]=status_id&op[status_id]=*&c[]=subject&c[]=issue_todo_list_titles.titles&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions` | The public project's issue list answers 200 for a non-member, without the plugin's columns |

## Problems

- /projects/e2e-project/settings as admin: HTTP 500, expected 200
- /projects/e2e-project/settings as manager: HTTP 500, expected 200
- /issues/1 as reporter: HTTP 403, expected 200
