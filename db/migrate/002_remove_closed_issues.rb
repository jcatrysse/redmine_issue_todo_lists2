class RemoveClosedIssues < ActiveRecord::Migration[4.2]
  def up
    unless column_exists? :issue_todo_lists, :remove_closed_issues
      add_column :issue_todo_lists, :remove_closed_issues, :boolean, :default => false, :null => false
    end
  end

  def down
    if column_exists? :issue_todo_lists, :remove_closed_issues
      remove_column :issue_todo_lists, :remove_closed_issues
    end
  end
end
