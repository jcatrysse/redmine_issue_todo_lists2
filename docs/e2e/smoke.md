# smoke

Run 2026-10-07T16:18:22.958Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](smoke-01.png) | admin | `/` | / (HTTP 200) |
| ![](smoke-02.png) | admin | `/projects/e2e-project` | /projects/e2e-project (HTTP 200) |
| ![](smoke-03.png) | admin | `/projects/e2e-project/issues` | /projects/e2e-project/issues (HTTP 200) |
| ![](smoke-04.png) | admin | `/issues/1` | /issues/1 (HTTP 200) |
| ![](smoke-05.png) | admin | `/projects/e2e-project/issues/new` | /projects/e2e-project/issues/new (HTTP 200) |
| ![](smoke-06.png) | admin | `/projects/e2e-project/settings` | /projects/e2e-project/settings (HTTP 200) |
| ![](smoke-07.png) | admin | `/my/page` | /my/page (HTTP 200) |
| ![](smoke-08.png) | admin | `/my/account` | /my/account (HTTP 200) |
| ![](smoke-09.png) | admin | `/admin` | /admin (HTTP 200) |
| ![](smoke-10.png) | admin | `/admin/plugins` | /admin/plugins (HTTP 200) |
| ![](smoke-11.png) | admin | `/settings/plugin/redmine_issue_todo_lists2` | /settings/plugin/redmine_issue_todo_lists2 (HTTP 200) |
| ![](smoke-12.png) | admin | `/projects/e2e-project/issue_todo_lists/1/items/1/edit` | /projects/e2e-project/issue_todo_lists/1/items/1/edit (HTTP 406) |
| ![](smoke-13.png) | admin | `/projects/e2e-project/issue_todo_lists` | /projects/e2e-project/issue_todo_lists (HTTP 200) |
| ![](smoke-14.png) | admin | `/projects/e2e-project/issue_todo_lists/new` | /projects/e2e-project/issue_todo_lists/new (HTTP 200) |
| ![](smoke-15.png) | admin | `/projects/e2e-project/issue_todo_lists/1/edit` | /projects/e2e-project/issue_todo_lists/1/edit (HTTP 200) |
| ![](smoke-16.png) | admin | `/projects/e2e-project/issue_todo_lists/1` | /projects/e2e-project/issue_todo_lists/1 (HTTP 200) |
