require_dependency 'queries_helper'

module RedmineIssueTodoLists
  module Patches
    module QueriesHelperPatch
      def column_content(column, issue)
        if column.name == :"issue_todo_list_titles.titles"
          issue.issue_todo_list_titles.titles(User.current).map do |todo_list|
            link_to todo_list.title, project_issue_todo_list_path(todo_list.project, todo_list)
          end.join(', ').html_safe
        else
          super
        end
      end
    end
  end
end

QueriesHelper.prepend(RedmineIssueTodoLists::Patches::QueriesyHelperPatch)
