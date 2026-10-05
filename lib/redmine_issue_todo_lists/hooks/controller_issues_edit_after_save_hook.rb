module RedmineIssueTodoLists
  module Hooks
    class ControllerIssuesEditAfterSaveHook < Redmine::Hook::ViewListener
      def controller_issues_edit_after_save(context = {})
        issue = context[:issue]
        selected_todo_lists = list_ids(context.dig(:params, :issue, :issue_todo_list_ids))
        return if selected_todo_lists.nil?

        # The lists the form offered; lists the user cannot view are left alone.
        todo_lists = IssueTodoList.visible.where(project_id: issue.project.self_and_ancestors.ids).includes(:project).to_a
        # The form sends the lists it showed as selected. Only what the user
        # changed is applied, so a form opened before someone else changed
        # the lists does not undo that. Without it (REST API) the selection
        # is taken as the full list.
        shown_todo_lists = list_ids(context.dig(:params, :issue_todo_list_ids_was))
        to_add = selected_todo_lists - (shown_todo_lists || [])
        to_remove = shown_todo_lists ? shown_todo_lists - selected_todo_lists : todo_lists.map(&:id) - selected_todo_lists

        todo_lists.select { |list| to_add.include?(list.id) }.each do |todo_list|
          next unless User.current.allowed_to?(:add_issue_todo_list_items, todo_list.project)
          next if issue.issue_todo_list_items.exists?(issue_todo_list_id: todo_list.id)

          # Not saved when the list removes closed issues and this one is closed.
          IssueTodoListItem.create(issue_todo_list: todo_list, issue: issue, position: todo_list.get_max_position)
        end

        todo_lists.select { |list| to_remove.include?(list.id) }.each do |todo_list|
          next unless User.current.allowed_to?(:remove_issue_todo_list_items, todo_list.project)

          issue.issue_todo_list_items.where(issue_todo_list_id: todo_list.id).destroy_all
        end
      end

      private

      # nil for anything that is neither a list of ids nor an id.
      def list_ids(value)
        return nil unless value.is_a?(Array) || value.is_a?(String)

        Array(value).flat_map { |id| id.to_s.split(',') }.map(&:to_i) - [0]
      end
    end
  end
end
