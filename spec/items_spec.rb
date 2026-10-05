# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'to-do list items' do
  let(:session) { new_session }
  let(:project) { Project.find(1) }
  let(:todo_list) { create_todo_list('Sprint') }
  let(:items_path) { "/projects/ecookbook/issue_todo_lists/#{todo_list.id}/items" }

  before do
    enable_todo_lists(project)
    login(session, 'jsmith')
  end

  def add_item(issue_id, comment = '')
    session.post items_path, :params => {:item => {:issue_id => issue_id, :comment => comment}}, :xhr => true
    expect(session.response.status).to eq(200)
    session.response.body
  end

  describe 'adding' do
    it 'adds an issue by number, with or without #' do
      add_item('#1', 'first')
      add_item('2')

      expect(todo_list.issue_todo_list_items.reload.map(&:issue_id)).to eq([1, 2])
    end

    it 'adds a text item when only a comment is given' do
      add_item('', 'Write release notes')

      expect(todo_list.issue_todo_list_items.reload.map(&:comment)).to eq(['Write release notes'])
    end

    it 'refuses an unknown issue instead of saving an empty item' do
      body = add_item('999999', 'typo')

      expect(todo_list.issue_todo_list_items.reload).to be_empty
      expect(body).to include(I18n.t(:error_issue_not_found_in_project))
    end

    it 'refuses an empty item' do
      body = add_item('', '')

      expect(todo_list.issue_todo_list_items.reload).to be_empty
      expect(body).to include(I18n.t(:issue_todo_lists_item_create_empty))
    end

    it 'refuses a closed issue on a list that removes closed issues' do
      todo_list.update!(:remove_closed_issues => true)
      closed = Issue.joins(:status).where(:project_id => 1, :issue_statuses => {:is_closed => true}).first
      body = add_item(closed.id.to_s)

      expect(todo_list.issue_todo_list_items.reload).to be_empty
      expect(body).to include(I18n.t(:issue_todo_lists_closed_issue_not_allowed))
    end
  end

  describe 'editing' do
    it 'stores the comment and only the fields the list includes' do
      todo_list.update!(:included_fields => %w[due_date])
      item = add_text_item(todo_list, 'old')

      session.get "#{items_path}/#{item.id}/edit", :xhr => true
      expect(session.response.body).to include('edit_item_data_0')

      session.put "#{items_path}/#{item.id}", :xhr => true, :params => {:item => {
        :comment => 'new', :data => [{:field => 'due_date', :value => '2026-10-20'}, {:field => 'subject', :value => 'x'}]
      }}

      item.reload
      expect(item.comment).to eq('new')
      expect(item.data_value('due_date')).to eq('2026-10-20')
      expect(item.data_value('subject')).to be_nil
    end
  end

  it 'keeps the values of fields the list no longer shows' do
    todo_list.update!(:included_fields => %w[due_date])
    item = add_text_item(todo_list, 'text', [{field: 'subject', value: 'kept'}, {field: 'due_date', value: '2026-10-01'}])

    session.put "#{items_path}/#{item.id}", :xhr => true, :params => {:item => {
      :comment => 'text', :data => [{:field => 'due_date', :value => '2026-10-20'}]
    }}

    item.reload
    expect(item.data_value('subject')).to eq('kept')
    expect(item.data_value('due_date')).to eq('2026-10-20')
  end

  describe 'removing' do
    let!(:items) do
      add_to_todo_list(todo_list, Issue.find(1), Issue.find(2), Issue.find(3))
      todo_list.issue_todo_list_items.to_a
    end

    it 'keeps the order numbers contiguous' do
      session.delete "#{items_path}/#{items[0].id}", :xhr => true

      expect(todo_list.issue_todo_list_items.reload.map(&:position)).to eq([1, 2])
    end

    # The issue sidebar removes items without JavaScript.
    it 'redirects to a local back_url, or to the list' do
      session.delete "#{items_path}/#{items[0].id}", :params => {:back_url => '/issues/1'}
      expect(session.response.location).to end_with('/issues/1')

      session.delete "#{items_path}/#{items[1].id}", :params => {:back_url => 'https://example.org/'}
      expect(session.response.location).to end_with("/projects/ecookbook/issue_todo_lists/#{todo_list.id}")

      session.delete "#{items_path}/#{items[2].id}"
      expect(session.response.status).to eq(302)
    end
  end
end
