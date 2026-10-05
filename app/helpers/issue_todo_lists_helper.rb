module IssueTodoListsHelper
  include SortHelper
  include QueriesHelper

  # Prevent render error for column_content()
  if Redmine::Plugin.installed?(:redmine_blocked_reason)
    include IssuesBlockedReasonHelper
  end

  def get_route_for_localize
    if ['new', 'create'].include? params[:action]
      return 'new'
    elsif ['edit', 'update'].include? params[:action]
      return 'edit'
    end
    params[:action]
  end

  # Lists of the issues' projects and their parents, where the user may use
  # the context menu. With a single issue, also the lists that hold it.
  def self.get_all_todo_lists_from_project_issues(issues)
    project_ids = issues.map(&:project).uniq.flat_map { |project| project.self_and_ancestors.ids }.uniq
    todo_lists = IssueTodoList.where(project_id: project_ids)
    todo_lists = todo_lists.or(IssueTodoList.where(id: issues[0].issue_todo_list_items.select(:issue_todo_list_id))) if issues.one?

    allowed_projects = Project.allowed_to(User.current, :add_issue_todo_list_items_context_menu)
    todo_lists.visible.where(project_id: allowed_projects.select(:id)).includes(:project).to_a.sort_by { |list| [list.title.to_s.downcase, list.id] }
  end

  # Columns shown for the items of a list, in the order of the query.
  def todo_list_issue_columns(todo_list, issue_query)
    if todo_list.included_columns.any?
      issue_query.available_columns.select { |column| todo_list.included_columns.include?(column.name.to_s) }
    else
      issue_query.available_columns.select { |column| issue_query.columns.include?(column) }
    end
  end

  def todo_list_items_to_csv(todo_list, items, issue_query)
    issue_columns = todo_list_issue_columns(todo_list, issue_query)
    # UTF-8 unless asked otherwise: there is no export dialog to pick one.
    Redmine::Export::CSV.generate(:encoding => params[:encoding].presence || 'UTF-8') do |csv|
      csv << ([l(:issue_todo_label_order)] + issue_columns.map { |c| c.caption.to_s } + [l(:field_comments)])

      items.each do |item|
        fields = [item.position]
        issue_columns.each do |column|
          fields << (item.issue ? csv_content(column, item.issue) : todo_list_item_data_value(todo_list, item, column))
        end
        fields << item.comment
        csv << fields
      end
    end
  end

  # The value of a text item for a column, when the list includes that field.
  def todo_list_item_data_value(todo_list, item, column)
    return nil unless todo_list.included_fields.include?(column.name.to_s)

    item.data_value(column.name)
  end
end
