class InitializeIncludedAttributes < ActiveRecord::Migration[4.2]
  def up
    empty = connection.quote([].to_yaml)

    change_column_default :issue_todo_lists, :included_columns, [].to_yaml
    change_column_default :issue_todo_lists, :included_fields,  [].to_yaml

    execute "UPDATE issue_todo_lists SET included_columns = #{empty} WHERE included_columns IS NULL"
    execute "UPDATE issue_todo_lists SET included_fields  = #{empty} WHERE included_fields  IS NULL"
  end

  def down
    change_column_default :issue_todo_lists, :included_columns, nil
    change_column_default :issue_todo_lists, :included_fields,  nil
  end
end
