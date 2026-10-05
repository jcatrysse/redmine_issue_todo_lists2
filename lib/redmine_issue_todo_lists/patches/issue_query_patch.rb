require_dependency 'issue_query'
module RedmineIssueTodoLists
  module Patches
    module IssueQueryPatch
      module InstanceMethods
        def initialize_available_filters_with_itdl
          initialize_available_filters_without_itdl
          return unless itdl_lists_viewable?

          add_available_filter("todo_lists_ids", :type => :list_optional, :values => lambda { issue_todo_lists_values }, :label => :issue_todo_lists_title)
        end

        def available_columns_with_itdl
          return @available_columns if @available_columns

          @available_columns = available_columns_without_itdl
          if itdl_lists_viewable?
            @available_columns << QueryAssociationColumn.new(
              :issue_todo_list_titles,
              :titles,
              :sortable => "itdl_titles.itdl_title",
              :caption => :issue_todo_lists_title
            )

            @available_columns << QueryAssociationColumn.new(
              :issue_todo_list_item_orders,
              :positions,
              :sortable => "itdl_positions.itdl_position",
              :caption => :issue_todo_list_item_order
            )
          end

          @available_columns
        end

        def issue_todo_lists_values
          itdl_visible_lists.includes(:project).order('project_id', 'title').map do |list|
            project_name = list.project.present? ? "#{list.project.name}: " : ''
            [project_name + list.title.to_s, list.id.to_s]
          end
        end

        # Like the columns, this looks at every list the user may view, also
        # lists of other projects; the values to pick from are the project's.
        def sql_for_todo_lists_ids_field(field, operator, value)
          lists = IssueTodoList.visible
          lists = lists.where(:id => value.map(&:to_i)) if ['=', '!'].include?(operator)
          issue_ids = itdl_items_in(lists).select(:issue_id).to_sql

          case operator
          when '=', '*'
            "#{Issue.table_name}.id IN (#{issue_ids})"
          when '!', '!*'
            "#{Issue.table_name}.id NOT IN (#{issue_ids})"
          end
        end

        # One row per issue, so sorting does not duplicate issues.
        def joins_for_order_statement_with_itdl(order_options)
          joins = [joins_for_order_statement_without_itdl(order_options)]
          if order_options.to_s.include?('itdl_positions.')
            positions = itdl_items_in(IssueTodoList.visible)
                        .select("#{IssueTodoListItem.table_name}.issue_id, MIN(#{IssueTodoListItem.table_name}.position) AS itdl_position")
                        .group("#{IssueTodoListItem.table_name}.issue_id")
            joins << "LEFT OUTER JOIN (#{positions.to_sql}) itdl_positions ON itdl_positions.issue_id = #{Issue.table_name}.id"
          end
          if order_options.to_s.include?('itdl_titles.')
            titles = itdl_items_in(IssueTodoList.visible)
                     .joins(:issue_todo_list)
                     .select("#{IssueTodoListItem.table_name}.issue_id, MIN(#{IssueTodoList.table_name}.title) AS itdl_title")
                     .group("#{IssueTodoListItem.table_name}.issue_id")
            joins << "LEFT OUTER JOIN (#{titles.to_sql}) itdl_titles ON itdl_titles.issue_id = #{Issue.table_name}.id"
          end
          joins.compact!
          joins.any? ? joins.join(' ') : nil
        end

        private

        # Lists the current user may view in the projects this query covers,
        # offered as filter values.
        def itdl_visible_lists
          lists = IssueTodoList.visible
          project ? lists.where(:project_id => itdl_project_ids) : lists
        end

        def itdl_items_in(lists)
          IssueTodoListItem.where.not(:issue_id => nil).where(:issue_todo_list_id => lists.select(:id))
        end

        def itdl_project_ids
          @itdl_project_ids ||= (project.self_and_ancestors.ids + project.self_and_descendants.ids).uniq
        end

        def itdl_lists_viewable?
          return @itdl_lists_viewable if defined?(@itdl_lists_viewable)

          scope = Project.allowed_to(User.current, :view_issue_todo_lists)
          scope = scope.where(:id => itdl_project_ids) if project
          @itdl_lists_viewable = scope.exists?
        end
      end
    end
  end
end

IssueQuery.include(RedmineIssueTodoLists::Patches::IssueQueryPatch::InstanceMethods)
IssueQuery.class_eval do
  alias_method :initialize_available_filters_without_itdl, :initialize_available_filters
  alias_method :initialize_available_filters, :initialize_available_filters_with_itdl
  alias_method :available_columns_without_itdl, :available_columns
  alias_method :available_columns, :available_columns_with_itdl
  alias_method :joins_for_order_statement_without_itdl, :joins_for_order_statement
  alias_method :joins_for_order_statement, :joins_for_order_statement_with_itdl
end
