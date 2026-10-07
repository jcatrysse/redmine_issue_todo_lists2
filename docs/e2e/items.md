# items

Run 2026-10-07T16:19:46.661Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](items-added.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | An issue by number, one with #, and a text item are added without reloading; the comment is formatted |
| ![](items-unknown-issue-refused.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | An unknown issue number is refused with an error, nothing is added |
| ![](items-empty-item-refused.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | An item without issue and without comment is refused |
| ![](items-edit-comment-form.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | The edit form opens under the list with the current comment |
| ![](items-edit-text-item-form.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | A text item offers the fields the list includes: a date field for the due date, text for the assignee |
| ![](items-edited.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | The changed comment and the text item's values are shown in the list |
| ![](items-removed.png) | manager | `/projects/e2e-project/issue_todo_lists/4` | After confirming, the item is removed and the order numbers stay contiguous |
| ![](items-closed-issue-refused.png) | manager | `/projects/e2e-project/issue_todo_lists/2` | A list that removes closed issues refuses a closed issue with an error |
| ![](items-viewer.png) | viewer | `/projects/e2e-project/issue_todo_lists/4` | A view-only member sees the items, without add, edit or remove |
