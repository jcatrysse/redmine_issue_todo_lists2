class ProjectIdentifierToId < ActiveRecord::Migration[4.2]
  def up
    # Add new column if it doesn't exist
    unless column_exists?(:issue_todo_lists, :project_id)
      add_column :issue_todo_lists, :project_id, :integer, null: true

      # Convert project_identifier to project_id
      IssueTodoList.find_each do |list|
        list.update(project_id: Project.find_by(identifier: list.project_identifier)&.id)
      end
    end

    # Remove old column if it exists
    if column_exists?(:issue_todo_lists, :project_identifier)
      remove_column :issue_todo_lists, :project_identifier
    end
  end

  def down
    # Revert back - Add old column if it doesn't exist
    unless column_exists?(:issue_todo_lists, :project_identifier)
      add_column :issue_todo_lists, :project_identifier, :string, null: true

      # Convert project_id back to project_identifier
      IssueTodoList.find_each do |list|
        list.update(project_identifier: Project.find_by(id: list.project_id)&.identifier)
      end
    end

    # Remove the new column if it exists
    if column_exists?(:issue_todo_lists, :project_id)
      remove_column :issue_todo_lists, :project_id
    end
  end
end
