class IssueTodoListItemOrders
  attr_reader :issue_todo_list_item

  def initialize(issue_todo_list_item)
    @issue_todo_list_item = issue_todo_list_item
  end

  def positions(user = User.current)
    visible_issue_todo_list_item(user).map(&:position).join(', ')
  end

  def visible?(user = User.current)
    visible_issue_todo_list_item(user).any?
  end

  private

  def visible_issue_todo_list_item(user)
    issue_todo_list_item.select { |item| item.issue_todo_list.visible?(user) }
  end
end
