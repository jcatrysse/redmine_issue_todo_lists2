# frozen_string_literal: true

require_relative 'spec_helper'

# The sidebar and the field on the issue form, and what saving the form does.
RSpec.describe 'issue pages' do
  let(:session) { new_session }
  let(:project) { Project.find(1) }
  let(:sprint) { create_todo_list('Sprint') }
  let(:backlog) { create_todo_list('Backlog') }

  before do
    enable_todo_lists(project)
    sprint
    backlog
    login(session, 'jsmith')
  end

  def sidebar
    session.get '/issues/1'
    expect(session.response.status).to eq(200)
    Nokogiri::HTML(session.response.body).at_css('#sidebar')
  end

  describe 'sidebar' do
    it 'offers to add to a list or to remove from it' do
      add_to_todo_list(sprint, Issue.find(1))
      entries = sidebar.css('li').select { |li| li.text.include?('eCookbook: ') }

      backlog_entry = entries.find { |li| li.text.include?('Backlog') }
      sprint_entry = entries.find { |li| li.text.include?('Sprint') }
      expect(backlog_entry.at_css('a[data-method="post"]')['href']).to include("/issue_todo_lists/#{backlog.id}/bulk_allocate_issues")
      expect(sprint_entry.at_css('a[data-method="delete"]')['title']).to eq(I18n.t(:issue_todo_lists_remove_item))
      expect(session.response.body).not_to match(/translation missing/i)
    end

    it 'offers no add for a closed issue on a list that removes closed issues' do
      sprint.update!(:remove_closed_issues => true)
      closed = Issue.joins(:status).where(:project_id => 1, :issue_statuses => {:is_closed => true}).first
      session.get "/issues/#{closed.id}"
      entry = Nokogiri::HTML(session.response.body).css('#sidebar li').find { |li| li.text.include?('Sprint') }

      expect(entry.at_css('a[data-method="post"]')).to be_nil

      # The context menu still offers it; adding then says why it did not work.
      session.post "/projects/ecookbook/issue_todo_lists/#{sprint.id}/bulk_allocate_issues",
                   :params => {:issue_ids => [closed.id], :list_count => 1, :back_url => "/issues/#{closed.id}"}
      session.follow_redirect!
      expect(session.response.body).to include(I18n.t(:issue_todo_lists_closed_issue_not_allowed))
      expect(sprint.issues.reload).to be_empty
    end

    it 'is not shown where the module is disabled, also not to an admin' do
      project.disable_module!(:issue_todo_lists)
      login(session, 'admin')

      expect(sidebar.text).not_to include(I18n.t(:issue_todo_lists_title))
    end

    it 'is not shown when switched off in the settings' do
      Setting.plugin_redmine_issue_todo_lists2 = {'show_in_issue_sidebar' => '', 'show_in_issue_edit' => '1'}

      expect(sidebar.text).not_to include(I18n.t(:issue_todo_lists_title))
    end
  end

  describe 'issue form' do
    it 'labels the list field' do
      session.get '/issues/1/edit'
      doc = Nokogiri::HTML(session.response.body)

      expect(doc.at_css('select#issue_issue_todo_list_ids')).not_to be_nil
      expect(doc.at_css('label[for="issue_issue_todo_list_ids"]')).not_to be_nil
    end

    it 'adds and removes the issue when saved' do
      add_to_todo_list(backlog, Issue.find(1))
      session.patch '/issues/1', :params => {:issue => {:issue_todo_list_ids => ['', sprint.id.to_s]}}

      expect(session.response.status).to eq(302)
      expect(sprint.issues.reload.ids).to eq([1])
      expect(backlog.issues.reload.ids).to eq([])
    end

    # The form only offers lists the user may view, so saving it must not
    # remove the issue from a list the user cannot view.
    it 'keeps the issue on a list the user may remove from but cannot view' do
      child = Project.find(5) # private child of project 1
      enable_todo_lists(child, role: Role.find(2))
      Role.find(3).add_permission!(:remove_issue_todo_list_items)
      Role.find(3).remove_permission!(:view_issue_todo_lists)
      user = User.create!(:login => 'listmember', :firstname => 'List', :lastname => 'Member', :mail => 'listmember@example.net',
                          :password => 'Password123!', :password_confirmation => 'Password123!')
      Member.create!(:project => project, :principal => user, :roles => [Role.find(3)])
      Member.create!(:project => child, :principal => user, :roles => [Role.find(2)])
      issue = Issue.where(:project_id => child.id, :is_private => false).first
      parent_list = create_todo_list('Parent plans')
      child_list = create_todo_list('Child plans', project: child)
      add_to_todo_list(parent_list, issue)

      login(session, 'listmember', 'Password123!')
      session.patch "/issues/#{issue.id}", :params => {:issue => {:issue_todo_list_ids => ['', child_list.id.to_s]}}

      expect(session.response.status).to eq(302)
      expect(child_list.issues.reload).to eq([issue])
      expect(parent_list.issues.reload).to eq([issue])
    end

    # The issue page holds the edit form from when it was loaded.
    describe 'a form opened before the lists changed' do
      it 'keeps an item added in the meantime when only a note is saved' do
        add_to_todo_list(sprint, Issue.find(1))
        sprint.issue_todo_list_items.first.update_column(:comment, 'added later')

        session.patch '/issues/1', :params => {:issue => {:notes => 'just a note', :issue_todo_list_ids => ['']},
                                               :issue_todo_list_ids_was => ''}

        expect(sprint.issue_todo_list_items.reload.map(&:comment)).to eq(['added later'])
      end

      it 'applies what the user changed in the form' do
        add_to_todo_list(backlog, Issue.find(1))
        session.patch '/issues/1', :params => {:issue => {:issue_todo_list_ids => ['', sprint.id.to_s]},
                                               :issue_todo_list_ids_was => backlog.id.to_s}

        expect(sprint.issues.reload.ids).to eq([1])
        expect(backlog.issues.reload.ids).to eq([])
      end

      it 'sends what it showed' do
        add_to_todo_list(backlog, Issue.find(1))
        session.get '/issues/1/edit'

        expect(Nokogiri::HTML(session.response.body).at_css('input[name="issue_todo_list_ids_was"]')['value']).to eq(backlog.id.to_s)
      end
    end

    it 'keeps the chosen lists when the form comes back with an error' do
      session.patch '/issues/1', :params => {:issue => {:subject => '', :issue_todo_list_ids => ['', backlog.id.to_s]},
                                             :issue_todo_list_ids_was => ''}
      doc = Nokogiri::HTML(session.response.body)

      expect(doc.css('select#issue_issue_todo_list_ids option[selected]').map { |o| o['value'] }).to eq([backlog.id.to_s])
      expect(backlog.issues.reload).to be_empty
    end

    it 'takes a single id, and ignores a value that is no id' do
      session.patch '/issues/1', :params => {:issue => {:issue_todo_list_ids => sprint.id.to_s}}
      expect(session.response.status).to eq(302)
      expect(sprint.issues.reload.ids).to eq([1])

      session.patch '/issues/1', :params => {:issue => {:subject => 'x', :issue_todo_list_ids => {'a' => 'b'}}}
      expect(session.response.status).to eq(302)
      expect(sprint.issues.reload.ids).to eq([1])
    end

    it 'adds a new issue to the selected list' do
      session.post '/projects/ecookbook/issues', :params => {
        :issue => {:tracker_id => 1, :subject => 'New one', :issue_todo_list_ids => ['', backlog.id.to_s]}
      }

      expect(session.response.status).to eq(302)
      expect(backlog.issues.reload.map(&:subject)).to eq(['New one'])
    end
  end

  describe 'list page' do
    it 'shows a view-only user the list without editing tools or script errors' do
      add_to_todo_list(sprint, Issue.find(1))
      add_text_item(sprint, 'A text item')
      Role.find(2).add_permission!(:view_issue_todo_lists)
      login(session, 'dlopper', 'foo')

      session.get "/projects/ecookbook/issue_todo_lists/#{sprint.id}"
      expect(session.response.status).to eq(200)
      doc = Nokogiri::HTML(session.response.body)

      # wikitoolbar_for without its textarea threw a TypeError in the browser
      expect(session.response.body).not_to include("'new_item_comment'")
      expect(doc.at_css('#new-item-form')).to be_nil
      expect(doc.at_css('#issue-todo-list-table.sortable')).to be_nil
      cells = doc.css('#issue-todo-list-table tbody tr').map { |tr| tr.css('> td').size }
      expect(cells.uniq.size).to eq(1)
      expect(doc.css('#issue-todo-list-table thead th').size).to eq(cells.first)
    end

    it 'shows the remove and edit buttons with a title' do
      add_to_todo_list(sprint, Issue.find(1))
      session.get "/projects/ecookbook/issue_todo_lists/#{sprint.id}"
      doc = Nokogiri::HTML(session.response.body)

      expect(doc.at_css('a.icon-link-break')['title']).to eq(I18n.t(:issue_todo_lists_remove_item))
      expect(doc.at_css('a.edit_item')['title']).to eq(I18n.t(:issue_todo_label_edit_comment))
      expect(session.response.body).not_to match(/translation missing/i)
    end

    it 'escapes the title once' do
      sprint.update!(:title => 'R&D <b>')
      session.get "/projects/ecookbook/issue_todo_lists/#{sprint.id}"
      doc = Nokogiri::HTML(session.response.body)

      expect(doc.at_css('title').text).to include('R&D <b>')
      expect(doc.at_css('#content h2').text).to include('R&D <b>')
    end

    it 'gives text items no context menu checkbox' do
      add_text_item(sprint, 'A text item')
      session.get "/projects/ecookbook/issue_todo_lists/#{sprint.id}"
      row = Nokogiri::HTML(session.response.body).at_css('#issue-todo-list-table tbody tr')

      expect(row['class']).not_to include('hascontextmenu')
      expect(row.at_css('input[type=checkbox]')).to be_nil
    end
  end
end
