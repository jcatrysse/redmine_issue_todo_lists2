# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'models' do
  let(:project) { Project.find(1) }
  let(:todo_list) { create_todo_list('Sprint') }

  before { enable_todo_lists(project) }

  it 'stores the included columns and item data as arrays' do
    todo_list.update!(:included_columns => %w[subject status], :included_fields => %w[due_date])
    item = add_text_item(todo_list, 'text', [{field: 'due_date', value: '2026-10-20'}])

    expect(IssueTodoList.find(todo_list.id).included_columns).to eq(%w[subject status])
    expect(IssueTodoListItem.find(item.id).data_value('due_date')).to eq('2026-10-20')
    stored = IssueTodoList.connection.select_value("SELECT included_columns FROM issue_todo_lists WHERE id = #{todo_list.id}")
    expect(stored).to start_with('---')
  end

  it 'reads included columns stored as a plain array string' do
    # As Redmine 5.1 wrote it before 2.4.0
    IssueTodoList.connection.execute(%(UPDATE issue_todo_lists SET included_columns = '["subject", "status"]' WHERE id = #{todo_list.id}))

    expect(IssueTodoList.find(todo_list.id).included_columns).to eq(%w[subject status])
  end

  it 'lets an admin delete a user who created or edited a list' do
    user = User.create!(:login => 'listowner', :firstname => 'List', :lastname => 'Owner', :mail => 'listowner@example.net',
                        :password => 'Password123!', :password_confirmation => 'Password123!')
    User.current = user
    list = create_todo_list('Theirs')
    list.update_columns(:created_by_id => user.id, :last_updated_by_id => user.id)
    User.current = User.find(1)

    expect { user.destroy }.not_to raise_error
    expect(User.exists?(user.id)).to be(false)
    expect(list.reload.created_by).to eq(User.anonymous)
    expect(list.last_updated_by).to eq(User.anonymous)
  end

  it 'renumbers a list and marks it updated when one of its issues is deleted' do
    add_to_todo_list(todo_list, Issue.find(1), Issue.find(2), Issue.find(3))
    todo_list.update_columns(:last_updated => 1.day.ago, :last_updated_by_id => User.find(1).id)
    User.current = User.find(2)

    Issue.find(2).destroy

    expect(todo_list.issue_todo_list_items.reload.map { |item| [item.issue_id, item.position] }).to eq([[1, 1], [3, 2]])
    expect(todo_list.reload.last_updated_by).to eq(User.find(2))
    expect(todo_list.last_updated).to be > 1.hour.ago
  end

  it 'deletes a list with its items' do
    add_to_todo_list(todo_list, Issue.find(1), Issue.find(2))

    expect { todo_list.destroy }.to change(IssueTodoListItem, :count).by(-2)
  end

  it 'takes out closed issues when remove closed issues is turned on' do
    closed = Issue.joins(:status).where(:project_id => 1, :issue_statuses => {:is_closed => true}).first
    add_to_todo_list(todo_list, Issue.find(1), closed)

    todo_list.update!(:remove_closed_issues => true)

    expect(todo_list.issues.reload).to eq([Issue.find(1)])
    expect(todo_list.issue_todo_list_items.map(&:position)).to eq([1])
  end

  it 'refuses a description or a comment longer than a MySQL TEXT column' do
    list = IssueTodoList.new(:project => project, :title => 'Long', :description => 'é' * 40_000, :created_by => User.find(1))
    expect(list).not_to be_valid
    expect(list.errors[:description]).not_to be_empty

    item = IssueTodoListItem.new(:issue_todo_list => todo_list, :comment => 'x' * 65_536, :position => 1)
    expect(item).not_to be_valid
    expect(item.errors[:comment]).not_to be_empty
  end

  it 'refuses a title longer than the column' do
    list = IssueTodoList.new(:project => project, :title => 'x' * 256, :created_by => User.find(1))

    expect(list).not_to be_valid
    expect(list.errors[:title]).not_to be_empty
  end

  describe 'closing an issue' do
    let(:closed_status) { IssueStatus.where(:is_closed => true).first }

    it 'removes it from lists that remove closed issues, and only from those' do
      keeps = create_todo_list('Keeps')
      todo_list.update!(:remove_closed_issues => true)
      issue = Issue.find(1)
      add_to_todo_list(todo_list, issue)
      add_to_todo_list(keeps, issue)

      issue.init_journal(User.find(1))
      issue.update!(:status => closed_status)

      expect(todo_list.issues.reload).to be_empty
      expect(keeps.issues.reload).to eq([issue])
    end

    it 'leaves the lists alone when something else changes' do
      todo_list.update!(:remove_closed_issues => true)
      issue = Issue.find(1)
      add_to_todo_list(todo_list, issue)

      issue.init_journal(User.find(1))
      issue.update!(:subject => 'Renamed')

      expect(todo_list.issues.reload).to eq([issue])
    end
  end

  it 'gives Liquid only the lists the user may view' do
    other = create_todo_list('Other', project: Project.find(2))
    add_to_todo_list(todo_list, Issue.find(4))
    add_to_todo_list(other, Issue.find(4))

    # jsmith is Developer of project 2, dlopper is no member there.
    enable_todo_lists(Project.find(2), role: Role.find(2))

    expect(Issue.find(4).todolists_with_positions(User.find(3)).map { |l| l[:title] }).to eq(['Sprint'])
    expect(Issue.find(4).todolists_with_positions(User.find(2)).map { |l| l[:title] }.sort).to eq(%w[Other Sprint])
  end
end
