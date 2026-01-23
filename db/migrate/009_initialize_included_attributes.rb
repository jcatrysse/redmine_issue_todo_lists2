class InitializeIncludedAttributes < ActiveRecord::Migration[4.2]
  def up
    empty = connection.quote([].to_yaml)

    # Fix: Remove the change_column_default line, as MySQL does not support default values for TEXT columns
    # use an UPDATE statement to populate existing empty data
    execute "UPDATE issue_todo_lists SET included_columns = #{empty} WHERE included_columns IS NULL"
    execute "UPDATE issue_todo_lists SET included_fields  = #{empty} WHERE included_fields  IS NULL"
  end

  def down
    # Fix: Cannot roll back the default value in MySQL (since setting it is not supported); setting it to nil is sufficient here
    change_column_default :issue_todo_lists, :included_columns, nil
    change_column_default :issue_todo_lists, :included_fields,  nil
  end
end
