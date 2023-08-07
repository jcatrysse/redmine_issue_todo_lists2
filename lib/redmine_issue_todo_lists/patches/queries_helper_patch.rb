require_dependency 'queries_helper'

module RedmineIssueTodoLists
  module Patches
    module QueriesHelperPatch
      module InstanceMethods
        def column_content_with_itdl(column, issue)
          if column.name == :"issue_todo_list_titles.titles"
            issue.issue_todo_list_titles.titles(User.current).map do |todo_list|
              link_to todo_list.title, project_issue_todo_list_path(todo_list.project, todo_list)
            end.join(', ').html_safe
          else
            column_content_without_itdl(column, issue)
          end
        end
      end
    end
  end
end

QueriesHelper.include(RedmineIssueTodoLists::Patches::QueriesHelperPatch::InstanceMethods)
QueriesHelper.class_eval do
  alias_method :column_content_without_itdl, :column_content
  alias_method :column_content, :column_content_with_itdl
end
