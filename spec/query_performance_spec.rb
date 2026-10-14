# frozen_string_literal: true

require_relative 'spec_helper'

# The to-do list columns of the issue list: their lists, positions and
# projects are loaded once for the page, not once per row. Only queries on
# this plugin's tables count, so other plugins' queries do not matter.
RSpec.describe 'issue list with the to-do list columns' do
  let(:project) { Project.find(1) }
  let(:session) { new_session }

  before do
    enable_todo_lists(project)
    # jsmith sees the lists of project 5 (member) and not those of project 2.
    other = Project.find(5)
    enable_todo_lists(other, role: User.find(2).roles_for_project(other).first)
    lists = [create_todo_list('Sprint'), create_todo_list('Backlog'), create_todo_list('Elsewhere', project: other)]
    hidden = create_todo_list('Hidden', project: Project.find(2))
    author = User.find(2)
    50.times do |i|
      issue = Issue.new(:project => project, :tracker => project.trackers.first, :author => author,
                        :subject => "Listed issue #{i}", :priority => IssuePriority.default || IssuePriority.first)
      issue.save!
      lists.each_with_index { |list, n| add_to_todo_list(list, issue) if (i + n).even? }
      add_to_todo_list(hidden, issue)
    end
    login(session, 'jsmith')
  end

  # The first `rows` listed issues, by an issue id filter: the CSV export
  # ignores per_page.
  def todo_list_queries(rows, format = nil)
    ids = Issue.where('subject LIKE ?', 'Listed issue %').order(:id).limit(rows).pluck(:id)
    queries = []
    counter = lambda do |*, payload|
      queries << payload[:sql] if payload[:name] != 'SCHEMA' && !payload[:cached] && payload[:sql] =~ /issue_todo_list/
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      session.get "/projects/ecookbook/issues#{format}", :params => {
        :set_filter => 1, :f => ['issue_id'], :op => {'issue_id' => '='}, :v => {'issue_id' => [ids.join(',')]},
        :c => ['subject', 'issue_todo_list_titles.titles', 'issue_todo_list_item_orders.positions'],
        :sort => 'id', :per_page => 100
      }
    end
    expect(session.response.status).to eq(200)
    queries
  end

  it 'runs as many queries for 50 rows as for 25' do
    few = todo_list_queries(25)
    many = todo_list_queries(50)

    expect(Nokogiri::HTML(session.response.body).css('table.issues tr.issue').size).to eq(50)
    expect(many.size).to eq(few.size), "25 rows: #{few.size} queries, 50 rows: #{many.size}"
  end

  it 'runs as many queries for the CSV export of 50 rows as for 25' do
    expect(todo_list_queries(50, '.csv').size).to eq(todo_list_queries(25, '.csv').size)
  end

  it 'shows the same titles, links and positions as before' do
    todo_list_queries(50)
    row = Nokogiri::HTML(session.response.body).css('table.issues tr.issue').find { |tr| tr.text.include?('Listed issue 0') }
    titles = row.css('td.issue_todo_list_titles-titles a')
    expect(titles.map(&:text)).to eq(%w[Elsewhere Sprint])
    expect(titles.map { |a| a['href'] }.first).to eq("/projects/private-child/issue_todo_lists/#{IssueTodoList.find_by(:title => 'Elsewhere').id}")
    issue = Issue.find_by(:subject => 'Listed issue 0')
    expect(row.at_css('td.issue_todo_list_item_orders-positions').text.strip)
      .to eq(issue.issue_todo_list_item_orders.positions(User.find(2)))
  end
end
