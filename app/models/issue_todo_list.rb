class IssueTodoList < ActiveRecord::Base
  belongs_to :project
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  belongs_to :last_updated_by, class_name: 'User', foreign_key: 'last_updated_by_id'

  has_many :issue_todo_list_items, -> { order('issue_todo_list_items.position ASC') }, dependent: :destroy
  has_many :issues, through: :issue_todo_list_items

  validates :title, presence: true
  before_save :force_updated

  serialize :included_columns, coder: YAML, type: Array
  serialize :included_fields, coder: YAML, type: Array
  attribute :included_columns, default: -> { [] }
  attribute :included_fields,  default: -> { [] }

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
  
  def visible?(user = User.current)
    user.allowed_to?(:view_issue_todo_lists, project, global: true)
  end

  private

  def normalize_array(value)
    value = YAML.safe_load(value) if value.is_a?(String)
    value.is_a?(Array) ? value : []
  rescue Psych::SyntaxError
    []
  end
end
