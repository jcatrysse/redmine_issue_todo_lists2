module RedmineIssueTodoLists
  module Patches
    module IssuePatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          after_save :remove_todo_list_allocations
          has_many :issue_todo_list_items, dependent: :destroy
          has_many :issue_todo_lists, through: :issue_todo_list_items
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def remove_todo_list_allocations
          return unless saved_change_to_status_id? && status&.is_closed?

          issue_todo_list_items.includes(:issue_todo_list).each do |item|
            item.destroy if item.issue_todo_list.remove_closed_issues
          end
        end

        # Lists the user may view that hold this issue, with its position in each.
        def todolists_with_positions(user = User.current)
          items = IssueTodoListItem.joins(:issue_todo_list)
                                   .where(issue_id: id, issue_todo_list_id: IssueTodoList.visible(user).select(:id))
                                   .includes(:issue_todo_list)
          items.map do |item|
            todolist = item.issue_todo_list
            {
              id: todolist.id,
              project_id: todolist.project_id,
              title: todolist.title,
              description: todolist.description,
              last_updated: todolist.last_updated,
              remove_closed_issues: todolist.remove_closed_issues,
              position: item.position
            }
          end
        end

        # Both columns use the same order, so titles and positions line up.
        def issue_todo_list_titles
          IssueTodoListTitles.new(issue_todo_lists.reorder("#{IssueTodoList.table_name}.title", "#{IssueTodoList.table_name}.id"))
        end

        def issue_todo_list_item_orders
          IssueTodoListItemOrders.new(
            issue_todo_list_items.joins(:issue_todo_list).includes(:issue_todo_list)
                                 .reorder("#{IssueTodoList.table_name}.title", "#{IssueTodoList.table_name}.id")
          )
        end
      end
    end
  end
end

Issue.include(RedmineIssueTodoLists::Patches::IssuePatch)
