module RedmineIssueTodoLists
  module Hooks
    class ViewIssuesDetailsBottomHook < Redmine::Hook::ViewListener
      render_on :view_issues_show_details_bottom, partial: 'issues/issue_todo_lists/issue_todo_lists_link'
    end
  end
end
