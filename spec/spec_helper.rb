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
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
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
