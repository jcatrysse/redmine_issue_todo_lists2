# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'to-do list pages' do
  let(:session) { new_session }
  let(:project) { Project.find(1) }
  let(:todo_list) { create_todo_list('Sprint') }
  let(:list_path) { "/projects/ecookbook/issue_todo_lists/#{todo_list.id}" }

  before do
    enable_todo_lists(project)
    login(session, 'jsmith')
  end

  describe 'create and update' do
    it 'shows the form with the error for a blank title' do
      session.post '/projects/ecookbook/issue_todo_lists', :params => {:issue_todo_list => {:title => ''}}
      expect(session.response.status).to eq(200)
      expect(session.response.body).to include('errorExplanation')

      session.patch list_path, :params => {:issue_todo_list => {:title => ''}}
      expect(session.response.status).to eq(200)
      expect(session.response.body).to include('errorExplanation')
      expect(todo_list.reload.title).to eq('Sprint')
      expect(Nokogiri::HTML(session.response.body).at_css('input[type=submit][name=commit]')['value']).to eq(I18n.t(:button_save))
    end

    it 'labels the column checkboxes without empty labels' do
      session.get "#{list_path}/edit"
      doc = Nokogiri::HTML(session.response.body)
      boxes = doc.css('#issue_todo_lists_include_columns input[type=checkbox]')

      expect(boxes).not_to be_empty
      expect(boxes.map { |b| b['aria-label'] }).to all(be_present)
      expect(doc.css('#issue_todo_lists_include_columns label')).to be_empty
    end

    it 'stores the included columns and fields' do
      session.post '/projects/ecookbook/issue_todo_lists',
                   :params => {:issue_todo_list => {:title => 'New', :included_columns => %w[subject status], :included_fields => %w[due_date]}}
      list = IssueTodoList.find_by(:title => 'New')

      expect(list.reload.included_columns).to eq(%w[subject status])
      expect(list.included_fields).to eq(%w[due_date])
    end

    it 'answers a missing form with 400, not 500' do
      session.post '/projects/ecookbook/issue_todo_lists'
      expect(session.response.status).to eq(400)
    end
  end

  it 'deletes a list and shows the notice as a flash' do
    session.delete list_path

    expect(session.response.location).to end_with('/projects/ecookbook/issue_todo_lists')
    session.follow_redirect!
    expect(session.response.body).to include(I18n.t(:issue_todo_lists_destroy_success))
    expect(IssueTodoList.exists?(todo_list.id)).to be(false)
  end

  describe 'CSV export' do
    it 'exports issue and text items' do
      todo_list.update!(:included_columns => %w[subject due_date], :included_fields => %w[due_date])
      add_to_todo_list(todo_list, Issue.find(1))
      add_text_item(todo_list, 'Write release notes', [{field: 'due_date', value: '2026-10-20'}])

      session.get "#{list_path}.csv"
      expect(session.response.status).to eq(200)
      expect(session.response.headers['Content-Type']).to include('text/csv')

      csv = session.response.body
      expect(csv).to include(Issue.find(1).subject)
      expect(csv).to include('Write release notes')
      expect(csv).to include('2026-10-20')
      expect(csv).not_to include('#<')
    end

    it 'writes UTF-8 with a BOM by default' do
      add_text_item(todo_list, 'Budget 500 € “quoted” 中文')

      session.get "#{list_path}.csv"
      csv = session.response.body.dup.force_encoding('UTF-8')
      expect(csv).to start_with("\uFEFF")
      expect(csv).to include('Budget 500 € “quoted” 中文')
    end
  end

  describe 'REST API' do
    before do
      Setting.rest_api_enabled = '1'
      todo_list.update!(:included_columns => %w[subject status], :included_fields => %w[due_date])
      add_to_todo_list(todo_list, Issue.find(1))
      add_text_item(todo_list, 'Text only', [{field: 'due_date', value: '2026-10-20'}])
    end

    let(:key) { User.find(2).api_key }

    it 'shows a list with text items as JSON and XML' do
      session.get "#{list_path}.json", :params => {:key => key}
      expect(session.response.status).to eq(200)
      items = JSON.parse(session.response.body)['todo_list_items']
      expect(items.map { |item| item.dig('issue', 'id') }).to eq([1, nil])
      expect(items.last['data']).to eq([{'field' => 'due_date', 'value' => '2026-10-20'}])

      session.get "#{list_path}.xml", :params => {:key => key}
      expect(session.response.status).to eq(200)
      expect(session.response.body).to include('<entry field="due_date" value="2026-10-20"/>')
      expect(session.response.body).to include('<project id="1" project_name="eCookbook"/>')
      expect(session.response.body).not_to include('=&gt;')
    end

    it 'keeps the JSON shape of an issue' do
      session.get "#{list_path}.json", :params => {:key => key}
      issue = JSON.parse(session.response.body)['todo_list_items'].first['issue']

      expect(issue['project']).to eq('id' => 1, 'project_name' => 'eCookbook')
      expect(issue['subject']).to eq(Issue.find(1).subject)
      expect(issue.keys).to include('tracker', 'status', 'priority', 'start_date', 'due_date', 'total_estimated_hours')
    end

    it 'lists the included columns as elements, not as a Ruby string' do
      session.get '/projects/ecookbook/issue_todo_lists.json', :params => {:key => key}
      list = JSON.parse(session.response.body)['todo_lists'].find { |l| l['id'] == todo_list.id }
      expect(list['included_columns']).to eq(%w[subject status])

      session.get '/projects/ecookbook/issue_todo_lists.xml', :params => {:key => key}
      expect(session.response.body).to include('<column>subject</column>')
      expect(session.response.body).not_to include('[&quot;subject')
    end
  end

  describe 'ordering' do
    let!(:items) do
      add_to_todo_list(todo_list, Issue.find(1), Issue.find(2), Issue.find(3))
      todo_list.issue_todo_list_items.to_a
    end

    it 'stores the posted order' do
      session.post "#{list_path}/update_item_order", :params => {:item => [items[2].id, items[0].id, items[1].id]}, :xhr => true

      expect(session.response.status).to eq(200)
      expect(todo_list.issue_todo_list_items.reload.map(&:issue_id)).to eq([3, 1, 2])
    end

    it 'keeps the place of items the user cannot see' do
      add_to_todo_list(todo_list, Issue.find(4))
      hidden = todo_list.issue_todo_list_items.reload.last
      # Order: issue 1, hidden issue 4, issue 2, issue 3
      hidden.update_column(:position, 2)
      items[1].update_column(:position, 3)
      items[2].update_column(:position, 4)
      enable_todo_lists(project, role: Role.find(2))
      login(session, 'dlopper', 'foo')

      session.post "#{list_path}/update_item_order", :params => {:item => [items[2].id, items[1].id, items[0].id]}, :xhr => true

      expect(todo_list.issue_todo_list_items.reload.map(&:issue_id)).to eq([3, 4, 2, 1])
      expect(hidden.reload.position).to eq(2)
    end

    it 'sends back the rows with the stored order' do
      session.post "#{list_path}/update_item_order", :params => {:item => [items[2].id, items[0].id, items[1].id]}, :xhr => true

      expect(session.response.body).to include("issue-todo-list-item-#{items[2].id}")
      expect(session.response.body.index("issue-todo-list-item-#{items[2].id}"))
        .to be < session.response.body.index("issue-todo-list-item-#{items[0].id}")
    end
  end
end
