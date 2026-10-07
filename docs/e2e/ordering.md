# ordering

Run 2026-10-07T16:20:13.581Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](ordering-before.png) | manager | `/projects/e2e-project/issue_todo_lists/1` | E2E sprint before ordering; the table is sortable for a member with the permission |
| ![](ordering-dragged.png) | manager | `/projects/e2e-project/issue_todo_lists/1` | The last item is dragged to the top; the order numbers follow and the change is posted |
| ![](ordering-reloaded.png) | manager | `/projects/e2e-project/issue_todo_lists/1` | After a reload the new order is still there, numbered from 1 without gaps |
| ![](ordering-viewer-not-sortable.png) | viewer | `/projects/e2e-project/issue_todo_lists/1` | A view-only member drags in vain: the table is not sortable and the order stays |
