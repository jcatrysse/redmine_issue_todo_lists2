# frozen_string_literal: true

require_relative 'spec_helper'

# Core fixtures: jsmith is Manager of project 1, dlopper Developer of project 1
# and rhill a member of nothing. Project 2 is private, issue 14 is a private
# issue in project 3 that dlopper cannot see.
RSpec.describe 'access control' do
  let(:session) { new_session }
  let(:project) { Project.find(1) }
  let(:other_project) { Project.find(2) }
  let(:todo_list) { create_todo_list('Sprint') }
  let(:allocate_path) { "/projects/ecookbook/issue_todo_lists/#{todo_list.id}/bulk_allocate_issues" }

  before do
    enable_todo_lists(project)
    enable_todo_lists(project, role: Role.find(2))
  end

  describe 'bulk_allocate_issues' do
    it 'sends an anonymous user to the login page and changes nothing' do
      session.post allocate_path, :params => {:issue_ids => [1], :list_count => 1, :back_url => 'https://example.org/'}

      expect(session.response.status).to eq(302)
      expect(session.response.location).to include('/login')
      expect(todo_list.issues.reload).to be_empty
    end

    it 'refuses a user who is no member' do
      login(session, 'rhill', 'foo')
      session.post allocate_path, :params => {:issue_ids => [1], :list_count => 1}

      expect(session.response.status).to eq(403)
      expect(todo_list.issues.reload).to be_empty
    end

    it 'refuses a member without one of the add permissions' do
      Role.find(2).remove_permission!(:add_issue_todo_list_items, :add_issue_todo_list_items_context_menu)
      login(session, 'dlopper', 'foo')
      session.post allocate_path, :params => {:issue_ids => [1], :list_count => 1}

      expect(session.response.status).to eq(403)
    end

    it 'lets the add permission add, but not unlist' do
      Role.find(2).remove_permission!(:add_issue_todo_list_items_context_menu, :remove_issue_todo_list_items)
      login(session, 'dlopper', 'foo')

      session.post allocate_path, :params => {:issue_ids => [1], :list_count => 1}
      expect(todo_list.issues.reload.ids).to eq([1])

      session.post allocate_path, :params => {:issue_ids => [1], :list_count => -1}
      expect(session.response.status).to eq(403)
      expect(todo_list.issues.reload.ids).to eq([1])
    end

    it 'ignores issues the user cannot see' do
      login(session, 'dlopper', 'foo')
      session.post allocate_path, :params => {:issue_ids => [4, 14], :list_count => 2}

      expect(session.response.status).to eq(404)
      expect(todo_list.issues.reload).to be_empty
    end

    # The menu was opened while the issue was listed; meanwhile it was removed.
    it 'does not add an issue for an unlist chosen in an outdated menu' do
      login(session, 'jsmith')
      session.post allocate_path, :params => {:issue_ids => [1], :list_count => -1}

      expect(todo_list.issues.reload).to be_empty
    end

    it 'adds the issues in the posted order' do
      login(session, 'jsmith')
      session.post allocate_path, :params => {:issue_ids => [3, 1, 2], :list_count => 3}

      expect(todo_list.issue_todo_list_items.reload.map(&:issue_id)).to eq([3, 1, 2])
    end

    it 'redirects to a local back_url only' do
      login(session, 'jsmith')
      session.post allocate_path, :params => {:issue_ids => [1], :list_count => 1, :back_url => 'https://example.org/'}
      expect(session.response.location).not_to include('example.org')
      expect(session.response.location).to end_with("/projects/ecookbook/issue_todo_lists/#{todo_list.id}")

      session.post allocate_path, :params => {:issue_ids => [2], :list_count => 1, :back_url => '/issues'}
      expect(session.response.location).to end_with('/issues')
    end
  end

  describe 'lists and items of another project' do
    let!(:foreign_list) { create_todo_list('Hidden plans', project: other_project) }
    let!(:foreign_item) { add_text_item(foreign_list, 'secret comment') }

    before { login(session, 'dlopper', 'foo') }

    it 'cannot be read, changed or deleted through a project the user belongs to' do
      base = "/projects/ecookbook/issue_todo_lists/#{foreign_list.id}"

      session.get base
      expect(session.response.status).to eq(404)
      session.get "#{base}.csv"
      expect(session.response.status).to eq(404)
      session.patch base, :params => {:issue_todo_list => {:title => 'changed'}}
      expect(session.response.status).to eq(404)
      session.delete base
      expect(session.response.status).to eq(404)
      session.post "#{base}/items", :params => {:item => {:issue_id => '', :comment => 'injected'}}, :xhr => true
      expect(session.response.status).to eq(404)

      expect(foreign_list.reload.title).to eq('Hidden plans')
      expect(foreign_list.issue_todo_list_items.map(&:comment)).to eq(['secret comment'])
    end

    it 'cannot have its items edited, reordered or removed through an own list' do
      own_path = "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
      second_item = add_text_item(foreign_list, 'second')
      last_updated = foreign_list.reload.last_updated

      session.delete "#{own_path}/items/#{foreign_item.id}", :xhr => true
      expect(session.response.status).to eq(404)
      session.put "#{own_path}/items/#{foreign_item.id}", :params => {:item => {:comment => 'changed'}}, :xhr => true
      expect(session.response.status).to eq(404)
      session.post "#{own_path}/update_item_order", :params => {:item => [second_item.id, foreign_item.id]}, :xhr => true

      expect(foreign_item.reload.comment).to eq('secret comment')
      expect(foreign_list.issue_todo_list_items.reload.map(&:id)).to eq([foreign_item.id, second_item.id])
      expect(foreign_list.reload.last_updated).to eq(last_updated)
    end
  end

  describe 'an item of an issue the user cannot see, in an own list' do
    let!(:visible_item) { add_to_todo_list(todo_list, Issue.find(1)) && todo_list.issue_todo_list_items.last }
    let!(:hidden_item) do
      add_to_todo_list(todo_list, Issue.find(4))
      todo_list.issue_todo_list_items.last.tap { |item| item.update_column(:comment, 'about issue 4') }
    end
    let(:items_path) { "/projects/ecookbook/issue_todo_lists/#{todo_list.id}/items" }

    before { login(session, 'dlopper', 'foo') }

    it 'cannot be opened, changed or removed' do
      session.get "#{items_path}/#{hidden_item.id}/edit", :xhr => true
      expect(session.response.status).to eq(404)
      session.put "#{items_path}/#{hidden_item.id}", :params => {:item => {:comment => 'changed'}}, :xhr => true
      expect(session.response.status).to eq(404)
      session.delete "#{items_path}/#{hidden_item.id}", :xhr => true
      expect(session.response.status).to eq(404)

      expect(hidden_item.reload.comment).to eq('about issue 4')
    end

    it 'keeps its place when the list is reordered' do
      session.post "/projects/ecookbook/issue_todo_lists/#{todo_list.id}/update_item_order",
                   :params => {:item => [hidden_item.id, visible_item.id]}, :xhr => true

      expect(hidden_item.reload.position).to eq(2)
      expect(visible_item.reload.position).to eq(1)
    end
  end

  # The item responses render the whole list.
  describe 'a member who may change items but not view lists' do
    before do
      Role.find(2).remove_permission!(:view_issue_todo_lists)
      add_text_item(todo_list, 'private plan')
      login(session, 'dlopper', 'foo')
    end

    it 'gets no list content from the item actions' do
      item = todo_list.issue_todo_list_items.first
      list_path = "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
      requests = [
        [:post, "#{list_path}/items", {:item => {:issue_id => '99999', :comment => ''}}],
        [:get, "#{list_path}/items/#{item.id}/edit", {}],
        [:put, "#{list_path}/items/#{item.id}", {:item => {:comment => 'x'}}],
        [:post, "#{list_path}/update_item_order", {:item => [item.id]}]
      ]
      requests.each do |method, path, params|
        session.send(method, path, :params => params, :xhr => true)
        expect(session.response.status).to eq(403), "#{method} #{path}"
        expect(session.response.body).not_to include('private plan')
      end
    end
  end

  describe 'issue columns on the list page' do
    before do
      todo_list.update!(:included_columns => %w[subject relations spent_hours last_updated_by])
      add_to_todo_list(todo_list, Issue.find(1))
      Setting.cross_project_issue_relations = '1'
      IssueRelation.create!(:issue_from => Issue.find(1), :issue_to => Issue.find(4), :relation_type => 'relates')
      Role.find(2).update!(:time_entries_visibility => 'own')
      Role.find(2).add_permission!(:view_time_entries)
      issue = Issue.find(1)
      issue.init_journal(User.find(1), 'private remark').private_notes = true
      issue.save!
    end

    # Core hides these through preloads in IssueQuery#issues.
    it 'show only what core shows in the issue list' do
      login(session, 'dlopper', 'foo')
      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
      row = Nokogiri::HTML(session.response.body).at_css('#issue-todo-list-table tbody tr')

      expect(row.at_css('td.relations').text.strip).to eq('')
      expect(row.to_html).not_to include('/issues/4')
      # 154.25 hours are logged on issue 1, none of them by dlopper
      expect(row.at_css('td.spent_hours').text).not_to include('154')
      expect(row.at_css('td.last_updated_by').text).not_to include('Redmine Admin')

      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}.csv"
      expect(session.response.body).not_to include('#4')
      expect(session.response.body).not_to include('154')
      expect(session.response.body).not_to include('Redmine Admin')
    end
  end

  describe 'issues the viewer cannot see' do
    before do
      add_to_todo_list(todo_list, Issue.find(1), Issue.find(4), Issue.find(14))
      Setting.rest_api_enabled = '1'
    end

    it 'are left out of the list page, the CSV and the API' do
      login(session, 'dlopper', 'foo')
      hidden = [Issue.find(4).subject, Issue.find(14).subject]

      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
      expect(session.response.status).to eq(200)
      expect(session.response.body).to include(Issue.find(1).subject)
      hidden.each { |subject| expect(session.response.body).not_to include(subject) }

      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}.csv"
      expect(session.response.status).to eq(200)
      hidden.each { |subject| expect(session.response.body).not_to include(subject) }

      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}.json", :params => {:key => User.find(3).api_key}
      ids = JSON.parse(session.response.body)['todo_list_items'].map { |item| item.dig('issue', 'id') }
      expect(ids).to eq([1])
    end

    it 'are all shown to a user who can see them' do
      login(session, 'jsmith')
      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"

      [1, 4, 14].each { |id| expect(session.response.body).to include(Issue.find(id).subject) }
    end
  end

  describe 'a closed project' do
    before do
      add_to_todo_list(todo_list, Issue.find(1))
      project.update_column(:status, Project::STATUS_CLOSED)
    end

    it 'keeps its lists readable and refuses changes' do
      login(session, 'jsmith')
      session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
      expect(session.response.status).to eq(200)

      session.post allocate_path, :params => {:issue_ids => [2], :list_count => 1}
      expect(session.response.status).to eq(403)
      expect(todo_list.issues.reload.ids).to eq([1])
    end
  end

  it 'gives an admin no list pages where the module is disabled' do
    todo_list
    project.disable_module!(:issue_todo_lists)
    login(session, 'admin')

    session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}"
    expect(session.response.status).to eq(403)
  end

  # The CSV link used to copy every request parameter, host included.
  it 'builds the CSV link without request parameters' do
    login(session, 'jsmith')
    session.get "/projects/ecookbook/issue_todo_lists/#{todo_list.id}", :params => {:host => 'evil.example', :protocol => 'javascript'}

    link = Nokogiri::HTML(session.response.body).at_css('p.other-formats a')
    expect(link['href']).to eq("/projects/ecookbook/issue_todo_lists/#{todo_list.id}.csv")
  end
end
