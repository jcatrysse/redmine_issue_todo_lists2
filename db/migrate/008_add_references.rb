class AddReferences < ActiveRecord::Migration[4.2]
  def up
    # Modifying issue_todo_lists
    change_table :issue_todo_lists do |t|
      t.rename :project_identifier, :project_id
      t.rename :created_by, :created_by_id
      t.rename :last_updated_by, :last_updated_by_id
    end

    add_foreign_key :issue_todo_lists, :projects
    add_foreign_key :issue_todo_lists, :users, column: :created_by_id
    add_foreign_key :issue_todo_lists, :users, column: :last_updated_by_id

    # Data validation and correction
    IssueTodoList.find_each do |list|
      unless Project.exists?(id: list.project_id)
        list.update!(project_id: Project.first.id) # Or any default project you want
      end

      unless User.exists?(id: list.created_by_id)
        list.update!(created_by_id: User.first.id) # Or any default user you want
      end

      unless User.exists?(id: list.last_updated_by_id)
        list.update!(last_updated_by_id: User.first.id) # Or any default user you want
      end
    end

    # Modifying issue_todo_list_items
    add_reference :issue_todo_list_items, :issue_todo_list, foreign_key: true, index: true
    add_reference :issue_todo_list_items, :issue, foreign_key: true, index: true
  end

  def down
    # Modifying issue_todo_lists
    remove_foreign_key :issue_todo_lists, :projects
    remove_foreign_key :issue_todo_lists, :users, column: :created_by_id
    remove_foreign_key :issue_todo_lists, :users, column: :last_updated_by_id

    change_table :issue_todo_lists do |t|
      t.rename :project_id, :project_identifier
      t.rename :created_by_id, :created_by
      t.rename :last_updated_by_id, :last_updated_by
    end

    # Modifying issue_todo_list_items
    remove_reference :issue_todo_list_items, :issue_todo_list, index: true
    remove_reference :issue_todo_list_items, :issue, index: true
  end
end
