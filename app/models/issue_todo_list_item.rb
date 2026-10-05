class IssueTodoListItem < ActiveRecord::Base
  belongs_to :issue_todo_list
  belongs_to :issue

  validates_presence_of :issue_todo_list
  validates_uniqueness_of :issue_id, :scope => :issue_todo_list_id, :allow_nil => true
  validate :issue_open_if_list_removes_closed, :on => :create
  # A TEXT column on MySQL holds 65,535 bytes.
  validate { errors.add(:comment, :too_long, count: 65_535) if comment.to_s.bytesize > 65_535 }

  before_save :force_updated
  before_destroy :force_updated
  after_destroy :renumber_list

  # See IssueTodoList: Rails 6.1 needs the positional form.
  if Rails.gem_version >= Gem::Version.new('7.1')
    serialize :data, coder: YAML, type: Array
  else
    serialize :data, Array
  end

  def force_updated
    return if list_being_destroyed?

    issue_todo_list&.mark_updated
  end

  def visible?(user = User.current)
    issue.nil? || issue.visible?(user)
  end

  # The value a text item holds for a column.
  def data_value(field)
    entry = Array(data).find { |d| d.is_a?(Hash) && (d[:field] || d['field']).to_s == field.to_s }
    entry && (entry[:value] || entry['value'])
  end

  private

  def issue_open_if_list_removes_closed
    return unless issue && issue_todo_list&.remove_closed_issues && issue.closed?

    errors.add(:base, ::I18n.t(:issue_todo_lists_closed_issue_not_allowed))
  end

  # True while the list deletes its items, not when a deleted issue does.
  def list_being_destroyed?
    destroyed_by_association&.active_record == IssueTodoList
  end

  # Keeps the order numbers contiguous after an item is removed.
  def renumber_list
    return if list_being_destroyed?

    IssueTodoListItem.where(issue_todo_list_id: issue_todo_list_id).order(:position, :id).each_with_index do |item, index|
      item.update_column(:position, index + 1) unless item.position == index + 1
    end
  end
end
