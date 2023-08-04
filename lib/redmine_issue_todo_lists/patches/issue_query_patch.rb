require_dependency 'issue_query'
module RedmineIssueTodoLists
  module Patches
    module IssueQueryPatch
      module InstanceMethods
        def initialize_available_filters
          super
          project_ids = project ? project.self_and_ancestors.ids + project.self_and_descendants.ids : User.current.projects.visible.pluck(:id)

          if User.current.admin? || project_ids.any? { |id| User.current.allowed_to?(:view_issue_todo_lists, Project.find(id)) }
            add_available_filter("todo_lists_ids", :type => :list_optional, values: issue_todo_lists_values, :label => :issue_todo_lists_title)
          end
        end

        def available_columns
          return @available_columns if @available_columns

          @available_columns = super
          project_ids = project ? project.self_and_ancestors.ids + project.self_and_descendants.ids : User.current.projects.visible.pluck(:id)

          if User.current.admin? || project_ids.any? { |id| User.current.allowed_to?(:view_issue_todo_lists, Project.find(id)) }
            @available_columns << QueryAssociationColumn.new(
              :issue_todo_list_titles,
              :titles,
              :sortable => "#{IssueTodoList.table_name}.id",
              :caption => :issue_todo_lists_title
            )

            @available_columns << QueryAssociationColumn.new(
              :issue_todo_list_item_orders,
              :positions,
              :sortable => "#{IssueTodoListItem.table_name}.position",
              :caption => :issue_todo_list_item_order
            )
          end

          @available_columns
        end

        def issue_todo_lists_values
          project_ids = project ? project.self_and_ancestors.ids + project.self_and_descendants : User.current.projects.visible.pluck(:id)
          todo_lists = IssueTodoList.where(project_id: project_ids).order('project_id', 'title')

          unless User.current.admin?
            todo_lists = todo_lists.select { |list| User.current.allowed_to?(:view_issue_todo_lists, list.project) }
          end

          todo_lists.map do |list|
            project_name = list.project.present? ? "#{list.project.name}: " : ''
            [project_name + list.title.to_s, list.id.to_s]
          end
        end

        def sql_for_todo_lists_ids_field(field, operator, value)
          # accepts a comma separated list of ids
          case operator
          when "="
            issue_ids = IssueTodoListItem.where(:issue_todo_list_id => value.map(&:to_i)).pluck(:issue_id)
            if issue_ids.present?
              "#{Issue.table_name}.id IN (#{issue_ids.join(",")})"
            else
              "1=0"
            end
          when "!"
            issue_ids = IssueTodoListItem.where(:issue_todo_list_id => value.map(&:to_i)).pluck(:issue_id)
            if issue_ids.present?
              "#{Issue.table_name}.id NOT IN (#{issue_ids.join(",")})"
            else
              "1=1"
            end
          when "!*"
            issue_ids = IssueTodoListItem.all.pluck(:issue_id)
            if issue_ids.present?
              "#{Issue.table_name}.id NOT IN (#{issue_ids.join(",")})"
            else
              "1=1"
            end
          when "*"
            issue_ids = IssueTodoListItem.all.pluck(:issue_id)
            if issue_ids.present?
              "#{Issue.table_name}.id IN (#{issue_ids.join(",")})"
            else
              "1=0"
            end
          end
        end

        def joins_for_order_statement(order_options)
          joins = [super]
          new_joins = []
          if order_options.include?("#{IssueTodoListItem.table_name}.position")
            new_joins << "LEFT OUTER JOIN #{IssueTodoListItem.table_name} ON #{IssueTodoListItem.table_name}.issue_id = #{Issue.table_name}.id"
          end
          if order_options.include?("#{IssueTodoList.table_name}.id")
            new_joins << "LEFT OUTER JOIN #{IssueTodoListItem.table_name} ON #{IssueTodoListItem.table_name}.issue_id = #{Issue.table_name}.id"
            new_joins << "LEFT OUTER JOIN #{IssueTodoList.table_name} ON #{IssueTodoList.table_name}.id = #{IssueTodoListItem.table_name}.issue_todo_list_id"
          end
          joins = joins + new_joins.uniq if new_joins.any?
          joins.compact!
          joins.any? ? joins.join(' ') : nil
        end

      end
    end
  end
end

IssueQuery.prepend(RedmineIssueTodoLists::Patches::IssueQueryPatch::InstanceMethods)
