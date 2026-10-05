class AddForeignKey < ActiveRecord::Migration[4.2]
  def up
    # Modifying issue_todo_lists
    unless column_exists?(:issue_todo_lists, :created_by_id)
      rename_column :issue_todo_lists, :created_by, :created_by_id
    end

    unless column_exists?(:issue_todo_lists, :last_updated_by_id)
      rename_column :issue_todo_lists, :last_updated_by, :last_updated_by_id
    end

    # A constraint that existing rows violate is skipped, not fatal
    add_foreign_key_if_possible :issue_todo_list_items, :issue_todo_lists, :issue_todo_list_id
    add_foreign_key_if_possible :issue_todo_list_items, :issues, :issue_id
    add_foreign_key_if_possible :issue_todo_lists, :users, :created_by_id
    add_foreign_key_if_possible :issue_todo_lists, :users, :last_updated_by_id
  end

  def down
    # Modifying issue_todo_lists
    if column_exists?(:issue_todo_lists, :created_by_id)
      remove_foreign_key_if_present :issue_todo_lists, :users, :created_by_id
      rename_column :issue_todo_lists, :created_by_id, :created_by
    end

    if column_exists?(:issue_todo_lists, :last_updated_by_id)
      remove_foreign_key_if_present :issue_todo_lists, :users, :last_updated_by_id
      rename_column :issue_todo_lists, :last_updated_by_id, :last_updated_by
    end

    # Modifying issue_todo_list_items
    remove_foreign_key_if_present :issue_todo_list_items, :issue_todo_lists, :issue_todo_list_id
    remove_foreign_key_if_present :issue_todo_list_items, :issues, :issue_id
  end

  private

  # The savepoint keeps a failed statement from aborting the whole
  # migration on PostgreSQL, so the rescue can carry on. Called on the
  # connection: a migration treats the first argument of an unknown method
  # as a table name.
  def add_foreign_key_if_possible(from_table, to_table, column)
    return if foreign_key_exists?(from_table, to_table, column: column)

    connection.transaction(requires_new: true) do
      connection.add_foreign_key from_table, to_table, column: column
    end
  rescue StandardError => e
    warn "Could not add foreign key constraint to #{from_table} for #{column}: #{e.message}"
  end

  def remove_foreign_key_if_present(from_table, to_table, column)
    return unless foreign_key_exists?(from_table, to_table, column: column)

    remove_foreign_key from_table, column: column
  rescue StandardError => e
    warn "Could not remove foreign key constraint from #{from_table} for #{column}: #{e.message}"
  end
end
