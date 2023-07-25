class TodoListIncludedColumns < ActiveRecord::Migration[4.2]
  def up
    # Add the new column if it doesn't exist
    unless column_exists?(:issue_todo_lists, :included_columns)
      add_column :issue_todo_lists, :included_columns, :text
    end
  end

  def down
    # Remove the column if it exists
    if column_exists?(:issue_todo_lists, :included_columns)
      remove_column :issue_todo_lists, :included_columns
    end
  end
end
