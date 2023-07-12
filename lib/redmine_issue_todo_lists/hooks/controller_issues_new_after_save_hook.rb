module RedmineIssueTodoLists
  module Hooks
    class ControllerIssuesNewAfterSaveHook < Redmine::Hook::ViewListener
      def controller_issues_new_after_save(context = {})
        selected_todo_lists = context.dig(:params, :issue, :issue_todo_list_ids)
        if selected_todo_lists && selected_todo_lists != ["0"] && selected_todo_lists != [""]
          issue = context[:issue]
          selected_todo_lists = selected_todo_lists.map(&:to_i)
          allowed_todo_lists = IssueTodoList.where(project_id: issue.project.self_and_ancestors.ids).order('project_id', 'title').select { |list| User.current.allowed_to?(:add_issue_todo_list_items, list.project) }
          selected_todo_lists &= allowed_todo_lists.map(&:id)
          if selected_todo_lists.count.positive?
            selected_todo_lists.each do |todo_list_id|
              todo_list = IssueTodoList.find_by_id(todo_list_id)
              next if todo_list.nil?

              issue_todo_list_item = IssueTodoListItem.new
              issue_todo_list_item.issue_todo_list = todo_list
              issue_todo_list_item.issue_id = issue.id
              issue_todo_list_item.position = todo_list.get_max_position
              issue_todo_list_item.save unless issue.issue_todo_list_items.find_by(issue_todo_list_id: todo_list_id)
            end
          end
        end
      end
    end
  end
end
