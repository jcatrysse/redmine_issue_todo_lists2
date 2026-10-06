# user_delete

Run 2026-10-06T20:05:50.683Z against http://127.0.0.1:3001.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](user_delete-created-by-leaver.png) | leaver1791317137678 | `/projects/e2e-project/issue_todo_lists/7` | A list created by the user who will be deleted |
| ![](user_delete-confirm-delete.png) | admin | `/users/9` | The administrator confirms the deletion of the account |
| ![](user_delete-deleted.png) | admin | `/users` | The account is deleted without an error |
| ![](user_delete-list-after.png) | manager | `/projects/e2e-project/issue_todo_lists/7` | The list is still there and names Anonymous as creator and last editor |
