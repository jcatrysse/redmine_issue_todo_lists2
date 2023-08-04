class IssueTodoListTitles
  attr_reader :issue_todo_lists

  def initialize(issue_todo_lists)
    @issue_todo_lists = issue_todo_lists
  end

  def titles(user = User.current)
    visible_issue_todo_lists(user)
  end

  def visible?(user = User.current)
    return true if user.admin?
    issue_todo_lists.any? { |list| list.visible?(user) }
  end

  private
  def visible_issue_todo_lists(user)
    return issue_todo_lists if user.admin?
    issue_todo_lists.select { |list| list.visible?(user) }
  end
end
