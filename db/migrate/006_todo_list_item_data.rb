class TodoListItemData < ActiveRecord::Migration[4.2]
  def up
    # Add the new column if it doesn't exist
    unless column_exists?(:issue_todo_list_items, :data)
      add_column :issue_todo_list_items, :data, :text
    end
  end

  def down
    # Remove the column if it exists
    if column_exists?(:issue_todo_list_items, :data)
      remove_column :issue_todo_list_items, :data
    end
  end
end
