module RedmineIssueTodoLists
  module Hooks
    class ViewIssuesFormDetailsBottomHook < Redmine::Hook::ViewListener
        render_on :view_issues_form_details_bottom, partial: 'issues/issue_todo_lists/issue_todo_lists_issues_form'
    end
  end
end
