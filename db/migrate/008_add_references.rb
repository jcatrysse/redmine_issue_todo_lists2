class AddReferences < ActiveRecord::Migration[4.2]
  def up
    # Modifying issue_todo_lists
    if column_exists?(:issue_todo_lists, :project_identifier)
      rename_column :issue_todo_lists, :project_identifier, :project_id
      IssueTodoList.reset_column_information
      IssueTodoList.all.each do |list|
        list.update!(project_id: Project.where(identifier: list.project_id).first&.id)
      end
    end

    unless column_exists?(:issue_todo_lists, :created_by_id)
      rename_column :issue_todo_lists, :created_by, :created_by_id
    end

    unless column_exists?(:issue_todo_lists, :last_updated_by_id)
      rename_column :issue_todo_lists, :last_updated_by, :last_updated_by_id
      IssueTodoList.reset_column_information
      IssueTodoList.where(last_updated_by_id: nil).each do |list|
        list.update!(last_updated_by_id: User.first.id) # Or any default user you want
      end
    end

    # Modifying issue_todo_list_items
    unless column_exists?(:issue_todo_list_items, :issue_todo_list_id)
      add_reference :issue_todo_list_items, :issue_todo_list, foreign_key: true, index: true
    end

    unless column_exists?(:issue_todo_list_items, :issue_id)
      add_reference :issue_todo_list_items, :issue, foreign_key: true, index: true
    end
  end

  def down
    # Modifying issue_todo_lists
    if column_exists?(:issue_todo_lists, :project_id)
      remove_foreign_key :issue_todo_lists, :projects
      rename_column :issue_todo_lists, :project_id, :project_identifier
    end

    if column_exists?(:issue_todo_lists, :created_by_id)
      remove_foreign_key :issue_todo_lists, :users, column: :created_by_id
      rename_column :issue_todo_lists, :created_by_id, :created_by
    end

    if column_exists?(:issue_todo_lists, :last_updated_by_id)
      remove_foreign_key :issue_todo_lists, :users, column: :last_updated_by_id
      rename_column :issue_todo_lists, :last_updated_by_id, :last_updated_by
    end

    # Modifying issue_todo_list_items
    if column_exists?(:issue_todo_list_items, :issue_todo_list_id)
      remove_foreign_key :issue_todo_list_items, :issue_todo_lists
      remove_reference :issue_todo_list_items, :issue_todo_list, index: true
    end

    if column_exists?(:issue_todo_list_items, :issue_id)
      remove_foreign_key :issue_todo_list_items, :issues
      remove_reference :issue_todo_list_items, :issue, index: true
    end
  end
end
