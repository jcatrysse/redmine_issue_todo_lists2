# frozen_string_literal: true

module RedmineIssueTodoLists
  module Settings
    # The settings form stores '1' and leaves out a cleared box; the defaults
    # are true. Anything else, like '' or '0', counts as off.
    def self.enabled?(key, settings = Setting.plugin_redmine_issue_todo_lists2)
      %w[1 true].include?(settings[key].to_s)
    end
  end
end
