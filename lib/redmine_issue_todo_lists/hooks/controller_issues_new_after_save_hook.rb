module RedmineIssueTodoLists
  module Hooks
    class ControllerIssuesNewAfterSaveHook < Redmine::Hook::ViewListener
      def controller_issues_new_after_save(context = {})
        selected_todo_lists = Array(context.dig(:params, :issue, :issue_todo_list_ids)).map { |id| id.to_s.to_i } - [0]
        return if selected_todo_lists.empty?

        issue = context[:issue]
        todo_lists = IssueTodoList.visible.where(id: selected_todo_lists, project_id: issue.project.self_and_ancestors.ids).includes(:project)
        todo_lists.select { |list| User.current.allowed_to?(:add_issue_todo_list_items, list.project) }.each do |todo_list|
          next if issue.issue_todo_list_items.exists?(issue_todo_list_id: todo_list.id)

          # Not saved when the list removes closed issues and this one is closed.
          IssueTodoListItem.create(issue_todo_list: todo_list, issue: issue, position: todo_list.get_max_position)
        end
      end
    end
  end
end
