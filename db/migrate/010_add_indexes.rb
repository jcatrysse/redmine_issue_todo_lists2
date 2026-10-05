# frozen_string_literal: true

class AddIndexes < ActiveRecord::Migration[4.2]
  INDEXES = [
    [:issue_todo_lists, [:project_id], 'index_issue_todo_lists_on_project_id'],
    [:issue_todo_list_items, [:issue_todo_list_id, :position], 'index_issue_todo_list_items_on_list_and_position'],
    # MySQL already indexes this foreign key column, so it is skipped there
    [:issue_todo_list_items, [:issue_id], 'index_issue_todo_list_items_on_issue_id']
  ].freeze

  def up
    INDEXES.each do |table, columns, name|
      add_index table, columns, name: name unless index_exists?(table, columns)
    end
  end

  # InnoDB drops its own foreign key index once one of these covers the
  # column, and then refuses to drop ours. Keep a plain index in its place.
  def down
    if Redmine::Database.mysql?
      [:issue_todo_list_id, :issue_id].each do |column|
        next unless foreign_key_exists?(:issue_todo_list_items, column: column)

        add_index :issue_todo_list_items, column unless index_exists?(:issue_todo_list_items, column)
      end
    end
    INDEXES.each do |table, columns, name|
      next unless index_name_exists?(table, name)
      next if index_needed_by_foreign_key?(table, columns)

      remove_index table, name: name
    end
  end

  private

  def index_needed_by_foreign_key?(table, columns)
    Redmine::Database.mysql? && columns.size == 1 && foreign_key_exists?(table, column: columns.first)
  end
end
