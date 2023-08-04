class IssueTodoListItemOrders
  attr_reader :issue_todo_list_item

  def initialize(issue_todo_list_item)
    @issue_todo_list_item = issue_todo_list_item
  end

  def positions(user = User.current)
    visible_issue_todo_list_item(user).pluck(:position).join(', ')
  end

  private
  def visible_issue_todo_list_item(user)
    return issue_todo_list_item if user.admin?
    issue_todo_list_item.select { |item| item.issue_todo_list.visible?(user) }
  end
end
