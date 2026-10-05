# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'issue query filter and columns' do
  let(:project) { Project.find(1) }
  let(:sprint) { create_todo_list('Sprint') }
  let(:backlog) { create_todo_list('Backlog') }

  before do
    enable_todo_lists(project)
    add_to_todo_list(sprint, Issue.find(1), Issue.find(2))
    add_to_todo_list(backlog, Issue.find(2), Issue.find(3))
    # A text item has no issue; it used to break the filter SQL.
    add_text_item(sprint, 'Write release notes')
  end

  def issue_ids(operator, values = [], user: User.find(2))
    User.current = user
    query = IssueQuery.new(:name => '_', :project => project)
    query.filters = {}
    query.add_filter('status_id', '*', [''])
    query.add_filter('todo_lists_ids', operator, values.empty? ? [''] : values.map(&:to_s))
    query.issues.map(&:id).sort
  end

  it 'filters on one or more lists, or on none' do
    expect(issue_ids('=', [sprint.id])).to eq([1, 2])
    expect(issue_ids('=', [sprint.id, backlog.id])).to eq([1, 2, 3])
    expect(issue_ids('*')).to eq([1, 2, 3])
    expect(issue_ids('!', [sprint.id])).not_to include(1, 2)
    expect(issue_ids('!', [sprint.id])).to include(3)
    expect(issue_ids('!*')).not_to include(1, 2, 3)
  end

  it 'ignores lists the user may not view' do
    enable_todo_lists(project, role: Role.find(2))
    other = create_todo_list('Other', project: Project.find(2))
    add_to_todo_list(other, Issue.find(4))
    User.current = User.find(3)
    values = IssueQuery.new(:project => project).available_filters['todo_lists_ids'][:values]

    expect(values.map(&:last)).not_to include(other.id.to_s)
    expect(issue_ids('=', [other.id], user: User.find(3))).to eq([])
  end

  it 'is not offered where the module is disabled, also not to an admin' do
    project.disable_module!(:issue_todo_lists)
    User.current = User.find(1)
    query = IssueQuery.new(:project => project)

    expect(query.available_filters.keys).not_to include('todo_lists_ids')
    expect(query.available_columns.map(&:name)).not_to include(:'issue_todo_list_titles.titles')
  end

  # The column shows lists of other projects too, so any/none and sorting
  # follow the same lists.
  it 'counts lists of other projects the user may view for any, none and sorting' do
    enable_todo_lists(Project.find(2), role: Role.find(2))
    other = create_todo_list('AAA other project', project: Project.find(2))
    add_to_todo_list(other, Issue.find(5))

    expect(issue_ids('*')).to include(5)
    expect(issue_ids('!*')).not_to include(5)

    User.current = User.find(2)
    query = IssueQuery.new(:name => '_', :project => project)
    query.filters = {}
    query.add_filter('status_id', '*', [''])
    query.add_filter('issue_id', '=', ['1,5'])
    query.sort_criteria = [['issue_todo_list_titles.titles', 'asc']]
    expect(query.issue_ids).to eq([5, 1])
  end

  describe 'sorting by a to-do list column' do
    %w[issue_todo_list_item_orders.positions issue_todo_list_titles.titles].each do |column|
      it "lists every issue once when sorted by #{column}" do
        User.current = User.find(2)
        query = IssueQuery.new(:name => '_', :project => project)
        query.filters = {}
        query.add_filter('status_id', '*', [''])
        query.sort_criteria = [[column, 'asc']]

        ids = query.issue_ids
        expect(ids.size).to eq(ids.uniq.size)
        expect(ids.size).to eq(query.issue_count)
      end
    end

    # Ties are broken by core with issues.id DESC.
    {'issue_todo_list_titles.titles' => [3, 2, 1], 'issue_todo_list_item_orders.positions' => [2, 1, 3]}.each do |column, expected|
      it "sorts on the first title or the lowest position: #{column}" do
        User.current = User.find(2)
        query = IssueQuery.new(:name => '_', :project => project)
        query.filters = {}
        query.add_filter('status_id', '*', [''])
        query.add_filter('issue_id', '=', ['1,2,3'])
        query.sort_criteria = [[column, 'asc']]

        expect(query.issue_ids).to eq(expected)
      end
    end
  end

  it 'shows an admin no list where the module is disabled' do
    project.disable_module!(:issue_todo_lists)
    User.current = User.find(1)

    expect(Issue.find(1).issue_todo_list_titles.titles).to eq([])
    expect(Issue.find(1).issue_todo_list_item_orders.positions).to eq('')
    expect(Issue.find(1).todolists_with_positions).to eq([])
  end

  it 'shows list titles, not Ruby objects, in the CSV export' do
    session = new_session
    login(session, 'jsmith')
    session.get '/projects/ecookbook/issues.csv', :params => {
      :set_filter => 1, :f => ['status_id'], :op => {'status_id' => '*'},
      :c => ['subject', 'issue_todo_list_titles.titles', 'issue_todo_list_item_orders.positions']
    }

    expect(session.response.status).to eq(200)
    expect(session.response.body).to include('Backlog, Sprint')
    expect(session.response.body).not_to include('#<')
  end

  it 'renders the issue list with the filter and both columns' do
    session = new_session
    login(session, 'jsmith')
    session.get '/projects/ecookbook/issues', :params => {
      :set_filter => 1, :f => ['status_id', 'todo_lists_ids'], :op => {'status_id' => '*', 'todo_lists_ids' => '='},
      :v => {'todo_lists_ids' => [sprint.id.to_s]}, :sort => 'issue_todo_list_item_orders.positions',
      :c => ['subject', 'issue_todo_list_titles.titles', 'issue_todo_list_item_orders.positions']
    }

    expect(session.response.status).to eq(200)
    expect(Nokogiri::HTML(session.response.body).css('table.issues tr.issue').size).to eq(2)
  end
end
