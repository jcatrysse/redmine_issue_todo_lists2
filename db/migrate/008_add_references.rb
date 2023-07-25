class AddReferences < ActiveRecord::Migration[4.2]
  def up
    # Modifying issue_todo_lists
    unless column_exists?(:issue_todo_lists, :created_by_id)
      rename_column :issue_todo_lists, :created_by, :created_by_id
    end

    unless column_exists?(:issue_todo_lists, :last_updated_by_id)
      rename_column :issue_todo_lists, :last_updated_by, :last_updated_by_id
    end

    # Modifying issue_todo_list_items
    begin
      add_reference :issue_todo_list_items, :issue_todo_list, foreign_key: true, index: true
    rescue StandardError => e
      warn "Could not add foreign key constraint to issue_todo_list_items for issue_todo_list: #{e.message}"
    end

    begin
      add_reference :issue_todo_list_items, :issue, foreign_key: true, index: true
    rescue StandardError => e
      warn "Could not add foreign key constraint to issue_todo_list_items for issue: #{e.message}"
    end
  end

  def down
    # Modifying issue_todo_lists
    if column_exists?(:issue_todo_lists, :created_by_id)
      begin
        remove_foreign_key :issue_todo_lists, :users, column: :created_by_id
      rescue StandardError => e
        warn "Could not remove foreign key constraint from issue_todo_lists for created_by_id: #{e.message}"
      end
      rename_column :issue_todo_lists, :created_by_id, :created_by
    end

    if column_exists?(:issue_todo_lists, :last_updated_by_id)
      begin
        remove_foreign_key :issue_todo_lists, :users, column: :last_updated_by_id
      rescue StandardError => e
        warn "Could not remove foreign key constraint from issue_todo_lists for last_updated_by_id: #{e.message}"
      end
      rename_column :issue_todo_lists, :last_updated_by_id, :last_updated_by
    end

    # Modifying issue_todo_list_items
    if column_exists?(:issue_todo_list_items, :issue_todo_list_id)
      begin
        remove_foreign_key :issue_todo_list_items, :issue_todo_lists
      rescue StandardError => e
        warn "Could not remove foreign key constraint from issue_todo_list_items for issue_todo_list_id: #{e.message}"
      end
      remove_reference :issue_todo_list_items, :issue_todo_list, index: true
    end

    if column_exists?(:issue_todo_list_items, :issue_id)
      begin
        remove_foreign_key :issue_todo_list_items, :issues
      rescue StandardError => e
        warn "Could not remove foreign key constraint from issue_todo_list_items for issue_id: #{e.message}"
      end
      remove_reference :issue_todo_list_items, :issue, index: true
    end
  end
end
