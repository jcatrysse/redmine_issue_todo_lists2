class IssueTodoList < ActiveRecord::Base
  belongs_to :project
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :last_updated_by, class_name: 'User', foreign_key: 'last_updated_by_id'

  has_many :issue_todo_list_items, -> { order('issue_todo_list_items.position ASC') }, dependent: :destroy
  has_many :issues, through: :issue_todo_list_items

  validates :title, presence: true, length: {maximum: 255}
  # A TEXT column on MySQL holds 65,535 bytes.
  validate { errors.add(:description, :too_long, count: 65_535) if description.to_s.bytesize > 65_535 }
  before_save :force_updated
  after_save :remove_closed_issues_now, if: -> { saved_change_to_remove_closed_issues? && remove_closed_issues }

  # Rails 7.1 takes the coder and type as keywords, Rails 6.1 (Redmine 5.1)
  # only positionally and silently ignores the keywords.
  if Rails.gem_version >= Gem::Version.new('7.1')
    serialize :included_columns, coder: YAML, type: Array
    serialize :included_fields, coder: YAML, type: Array
  else
    serialize :included_columns, Array
    serialize :included_fields, Array
  end

  # Lists of projects where the user may view to-do lists. Takes the module,
  # the project status and admin rights into account like core does. A
  # subquery rather than a join, so it can sit inside an issue query that
  # joins projects itself.
  scope :visible, lambda { |*args|
    user = args.shift || User.current
    where(project_id: Project.allowed_to(user, :view_issue_todo_lists, *args).select(:id))
  }

  def included_columns=(value)
    super(normalize_array(value))
  end

  def included_fields=(value)
    super(normalize_array(value))
  end

  def included_columns
    normalize_array(super)
  end

  def included_fields
    normalize_array(super)
  end

  def to_s
    title.to_s
  end

  def get_max_position
    max = IssueTodoListItem.where(issue_todo_list_id: self.id).maximum(:position)
    max = 0 if max.nil?
    max + 1
  end

  def force_updated
    self.last_updated = current_time_from_proper_timezone

    if has_attribute?(:last_updated_by_id)
      self.last_updated_by = User.current
    elsif has_attribute?(:last_updated_by)
      self[:last_updated_by] = User.current
    end
  end

  # Records a change to the items without saving the whole list.
  def mark_updated
    return unless persisted?

    update_columns(last_updated: current_time_from_proper_timezone, last_updated_by_id: User.current.id)
  end

  # Text items and items of issues the user can see.
  def visible_items(user = User.current)
    issue_todo_list_items.where(issue_id: nil)
                         .or(issue_todo_list_items.where(issue_id: Issue.visible(user).select(:id)))
  end

  # The visible items with their issues, prepared for the issue columns.
  # Core only hides spent time, relations and private notes through these
  # preloads (see IssueQuery#issues); without them the raw values show.
  def visible_items_for_display(user = User.current)
    items = visible_items(user).includes(:issue).to_a
    issues = items.map(&:issue).compact
    if issues.any?
      Issue.load_visible_spent_hours(issues, user)
      Issue.load_visible_total_spent_hours(issues, user)
      Issue.load_visible_last_updated_by(issues, user)
      Issue.load_visible_relations(issues, user)
      Issue.load_visible_last_notes(issues, user)
    end
    items
  end

  # Turning the option on also takes out the issues that are closed already.
  def remove_closed_issues_now
    issue_todo_list_items.joins(issue: :status).where(issue_statuses: {is_closed: true}).destroy_all
  end

  def visible?(user = User.current)
    user.allowed_to?(:view_issue_todo_lists, project)
  end

  private

  def normalize_array(value)
    value = YAML.safe_load(value) if value.is_a?(String)
    value.is_a?(Array) ? value : []
  rescue Psych::SyntaxError
    []
  end
end
