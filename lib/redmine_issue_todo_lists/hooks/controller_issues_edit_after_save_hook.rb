module RedmineIssueTodoLists
  module Hooks
    class ControllerIssuesEditAfterSaveHook < Redmine::Hook::ViewListener
      def controller_issues_edit_after_save(context = {})
        issue = context[:issue]
        if (selected_todo_lists = context.dig(:params, :issue, :issue_todo_list_ids))
          allowed_todo_lists_add = IssueTodoList.where(project_id: issue.project.self_and_ancestors.ids).order('project_id', 'title').select { |list| User.current.allowed_to?(:add_issue_todo_list_items, list.project) }
          allowed_todo_lists_remove = IssueTodoList.where(project_id: issue.project.self_and_ancestors.ids).order('project_id', 'title').select { |list| User.current.allowed_to?(:remove_issue_todo_list_items, list.project) }
          selected_todo_lists = selected_todo_lists.map(&:to_i)

          (allowed_todo_lists_add.map(&:id) & selected_todo_lists).each do |todo_list_id|
            todo_list = IssueTodoList.find_by_id(todo_list_id)
            next if todo_list.nil?

            issue_todo_list_item = IssueTodoListItem.new
            issue_todo_list_item.issue_todo_list = todo_list
            issue_todo_list_item.issue_id = issue.id
            issue_todo_list_item.position = todo_list.get_max_position
            issue_todo_list_item.save unless issue.issue_todo_list_items.find_by(issue_todo_list_id: todo_list_id) || (todo_list.remove_closed_issues && issue.status.is_closed)
          end

          (allowed_todo_lists_remove.map(&:id) - selected_todo_lists).each do |todo_list_id|
            item_to_remove = issue.issue_todo_list_items.find_by(issue_todo_list_id: todo_list_id)
            item_to_remove.destroy if item_to_remove
          end
        end
      end
    end
  end
end
