module RedmineIssueTodoLists
  module Patches
    module ProjectPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          has_many :issue_todo_lists, dependent: :destroy
        end
      end

      module ClassMethods
      end

      module InstanceMethods
      end
    end
  end
end

Project.include(RedmineIssueTodoLists::Patches::ProjectPatch)
