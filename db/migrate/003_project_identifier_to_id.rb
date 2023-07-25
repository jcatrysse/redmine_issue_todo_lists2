class ProjectIdentifierToId < ActiveRecord::Migration[4.2]
  def up
    add_column :issue_todo_lists, :project_id, :integer, null: true, after: :id

    # project_identifier => project_id (as identifier is not unique use LIMIT)
    IssueTodoList.all.each do |list|
      list.update(project_id: Project.where(identifier: list.project_identifier).first&.id)
    end

    remove_column :issue_todo_lists, :project_identifier
  end

  def down
    add_column :issue_todo_lists, :project_identifier, :string, null: true, after: :id

    # project_id => project_identifier
    IssueTodoList.all.each do |list|
      list.update(project_identifier: Project.where(id: list.project_id).first&.identifier)
    end

    remove_column :issue_todo_lists, :project_id
  end
end
class ProjectIdentifierToId < ActiveRecord::Migration[4.2]
  def up
    add_column :issue_todo_lists, :project_id, :integer, null: true, after: :id

    # project_identifier => project_id (as identifier is not unique use LIMIT)
    IssueTodoList.all.each do |list|
      list.update(project_id: Project.where(identifier: list.project_identifier).first&.id)
    end

    remove_column :issue_todo_lists, :project_identifier
  end

  def down
    add_column :issue_todo_lists, :project_identifier, :string, null: true, after: :id

    # project_id => project_identifier
    IssueTodoList.all.each do |list|
      list.update(project_identifier: Project.where(id: list.project_id).first&.identifier)
    end

    remove_column :issue_todo_lists, :project_id
  end
end
