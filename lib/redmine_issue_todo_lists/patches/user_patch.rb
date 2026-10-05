# frozen_string_literal: true

module RedmineIssueTodoLists
  module Patches
    # The lists keep a foreign key to their creator and last editor. Like core
    # does for issues and journals, hand those over to the anonymous user so an
    # administrator can still delete the account.
    module UserPatch
      def self.included(base)
        base.class_eval do
          before_destroy :remove_issue_todo_list_references
        end
      end

      def remove_issue_todo_list_references
        return if id.nil?

        substitute = User.anonymous
        IssueTodoList.where(created_by_id: id).update_all(created_by_id: substitute.id)
        IssueTodoList.where(last_updated_by_id: id).update_all(last_updated_by_id: substitute.id)
      end
    end
  end
end

User.include(RedmineIssueTodoLists::Patches::UserPatch)
