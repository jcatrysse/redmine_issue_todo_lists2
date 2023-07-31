class CreateTodoLists < ActiveRecord::Migration[4.2]
  def up
    unless table_exists? :issue_todo_lists
      create_table :issue_todo_lists do |t|
        t.string :project_identifier
        t.string :title
        t.text :description
        t.integer :created_by
        t.datetime :last_updated
        t.integer :last_updated_by
      end
    end

    unless table_exists? :issue_todo_list_items
      create_table :issue_todo_list_items do |t|
        t.integer :issue_todo_list_id
        t.integer :issue_id
        t.integer :position
      end
    end
  end

  def down
    drop_table :issue_todo_lists if table_exists? :issue_todo_lists
    drop_table :issue_todo_list_items if table_exists? :issue_todo_list_items
  end
end
