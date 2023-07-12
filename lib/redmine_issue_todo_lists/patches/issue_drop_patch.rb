module RedmineIssueTodoLists
  module Patches
    module IssueDropPatch
      def self.included(base)
        base.class_eval do
          base.send(:include, InstanceMethods)
        end
      end
      module InstanceMethods
        def todolists_with_positions
          todolists = @issue.todolists_with_positions
          RedmineIssueTodoLists::Liquid::TodoListsDrop.new(todolists)
        end
      end
    end
  end

  if defined?(RedmineCrm::Liquid::IssueDrop)
    RedmineCrm::Liquid::IssueDrop.include(RedmineIssueTodoLists::Patches::IssueDropPatch)
  end
end
