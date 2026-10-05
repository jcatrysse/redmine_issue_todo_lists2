# frozen_string_literal: true

# Boots a real Redmine so that the hooks, views and settings are exercised the
# way a browser reaches them: through the router, the controllers and a real
# database loaded with Redmine's own fixtures.
#
# Run from the Redmine root:
#   RAILS_ENV=test bundle exec rspec plugins/redmine_issue_todo_lists2/spec

ENV['RAILS_ENV'] ||= 'test'

REDMINE_ROOT = File.expand_path('../../..', __dir__)
require File.join(REDMINE_ROOT, 'config', 'environment')

require 'rspec'
# Not autoloaded on Rails 6.1 (Redmine 5.x), which only pulls it in from its own
# test helper.
require 'active_record/fixtures'

FIXTURES_PATH = File.join(REDMINE_ROOT, 'test', 'fixtures')
FIXTURE_NAMES = Dir[File.join(FIXTURES_PATH, '*.yml')].map { |f| File.basename(f, '.yml') }.sort.freeze

RITL_ROOT = File.expand_path('..', __dir__)

module RitlSpecHelpers
  def plugin
    Redmine::Plugin.find(:redmine_issue_todo_lists2)
  end

  def new_session
    ActionDispatch::Integration::Session.new(Rails.application)
  end

  def login(session, login, password = login)
    session.post '/login', :params => {:username => login, :password => password}
  end

  def create_todo_list(title, project: Project.find(1))
    IssueTodoList.create!(:project => project, :title => title, :created_by => User.find(1))
  end

  def add_to_todo_list(todo_list, *issues)
    issues.each do |issue|
      IssueTodoListItem.create!(:issue_todo_list => todo_list, :issue => issue,
                                :position => todo_list.get_max_position)
    end
  end

  def add_text_item(todo_list, comment, data = [])
    IssueTodoListItem.create!(:issue_todo_list => todo_list, :comment => comment, :data => data,
                              :position => todo_list.get_max_position)
  end

  RITL_PERMISSIONS = [:add_issue_todo_lists, :view_issue_todo_lists, :edit_issue_todo_lists, :delete_issue_todo_lists, :add_issue_todo_list_items, :order_issue_todo_list_items,
                      :remove_issue_todo_list_items, :update_issue_todo_list_items, :add_issue_todo_list_items_context_menu].freeze

  # Turns the module on and gives the role the listed plugin permissions,
  # all of them by default.
  def enable_todo_lists(project, role: Role.find(1), permissions: RITL_PERMISSIONS)
    project.enable_module!(:issue_todo_lists)
    permissions.each { |permission| role.add_permission!(permission) }
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  # A typo in a path or filter must not pass as a green run.
  config.fail_if_no_examples = true
  config.include RitlSpecHelpers

  config.before(:suite) do
    ActiveRecord::FixtureSet.create_fixtures(FIXTURES_PATH, FIXTURE_NAMES)
  end

  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.before(:each) do
    User.current = User.find(1) # admin
    I18n.locale = :en
    Setting.clear_cache
  end

  config.after(:each) do
    User.current = nil
  end
end
