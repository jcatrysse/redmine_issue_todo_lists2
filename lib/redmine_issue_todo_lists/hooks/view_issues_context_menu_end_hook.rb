module RedmineIssueTodoLists
  module Hooks
    class ViewIssuesContextMenuEndHook < Redmine::Hook::ViewListener
      def view_issues_context_menu_end(context={})
        # Collect all to-do lists of all projects
        context[:todo_lists] = IssueTodoListsHelper.get_all_todo_lists_from_project_issues(context[:issues])
        # The selected issues each list already holds, by list id
        context[:listed_issue_ids] = IssueTodoListItem.where(issue_todo_list_id: context[:todo_lists].map(&:id), issue_id: context[:issues].map(&:id))
                                                      .pluck(:issue_todo_list_id, :issue_id)
                                                      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(list_id, issue_id), h| h[list_id] << issue_id }

        context[:controller].send(:render_to_string, {
          :partial => 'context_menus/issue_todo_lists/issues_context_menu',
          :locals => context
        })
      end
    end
  end
end
