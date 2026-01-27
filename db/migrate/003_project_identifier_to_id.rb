class ProjectIdentifierToId < ActiveRecord::Migration[4.2]
  def up
    unless column_exists?(:issue_todo_lists, :project_id)
      add_column :issue_todo_lists, :project_id, :integer, null: true

      # Improve cross‑DB compatibility
      execute <<~SQL.squish
        UPDATE issue_todo_lists
        SET project_id = (
          SELECT projects.id
          FROM projects
          WHERE projects.identifier = issue_todo_lists.project_identifier
        )
        WHERE project_identifier IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM projects
            WHERE projects.identifier = issue_todo_lists.project_identifier
          )
      SQL
    end

    remove_column :issue_todo_lists, :project_identifier if column_exists?(:issue_todo_lists, :project_identifier)
  end

  def down
    unless column_exists?(:issue_todo_lists, :project_identifier)
      add_column :issue_todo_lists, :project_identifier, :string, null: true

      # Improve cross‑DB compatibility
      execute <<~SQL.squish
        UPDATE issue_todo_lists
        SET project_identifier = (
          SELECT projects.identifier
          FROM projects
          WHERE projects.id = issue_todo_lists.project_id
        )
        WHERE project_id IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM projects
            WHERE projects.id = issue_todo_lists.project_id
          )
      SQL
    end

    remove_column :issue_todo_lists, :project_id if column_exists?(:issue_todo_lists, :project_id)
  end
end
