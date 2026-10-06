# issue_form

Run 2026-10-06T19:49:36.377Z against http://127.0.0.1:3000.

| screenshot | user | URL | shows |
|---|---|---|---|
| ![](issue_form-new-form.png) | manager | `/projects/e2e-project/issues/new` | The new issue form offers the project's to-do lists; E2E cleanup is chosen |
| ![](issue_form-new-listed.png) | manager | `/projects/e2e-project/issue_todo_lists/2` | The new issue is on E2E cleanup |
| ![](issue_form-edit-form.png) | manager | `/issues/8/edit` | Editing: E2E sprint chosen, E2E cleanup no longer |
| ![](issue_form-edited.png) | manager | `/issues/8` | The sidebar shows the issue on E2E sprint (remove button) and not on E2E cleanup (add button) |
| ![](issue_form-invalid-kept.png) | manager | `/issues/8` | A blank subject is refused; the form keeps both chosen lists |
| ![](issue_form-reporter-no-field.png) | reporter | `/projects/e2e-project/issues/new` | A member without the plugin's permissions gets the issue form without the to-do list field |
