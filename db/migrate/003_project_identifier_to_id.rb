class ProjectIdentifierToId < ActiveRecord::Migration[4.2]
  def up
    unless column_exists?(:issue_todo_lists, :project_id)
      add_column :issue_todo_lists, :project_id, :integer, null: true

      # Changed UPDATE FROM to INNER JOIN to comply with MySQL syntax
      execute <<~SQL.squish
        UPDATE issue_todo_lists
        INNER JOIN projects ON issue_todo_lists.project_identifier = projects.identifier
        SET issue_todo_lists.project_id = projects.id
      SQL
    end

    remove_column :issue_todo_lists, :project_identifier if column_exists?(:issue_todo_lists, :project_identifier)
  end

  def down
    unless column_exists?(:issue_todo_lists, :project_identifier)
      add_column :issue_todo_lists, :project_identifier, :string, null: true

      # Changed UPDATE FROM to INNER JOIN to comply with MySQL syntax
      execute <<~SQL.squish
        UPDATE issue_todo_lists
        INNER JOIN projects ON issue_todo_lists.project_id = projects.id
        SET issue_todo_lists.project_identifier = projects.identifier
      SQL
    end

    remove_column :issue_todo_lists, :project_id if column_exists?(:issue_todo_lists, :project_id)
  end
end
