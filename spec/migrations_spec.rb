# frozen_string_literal: true

require_relative 'spec_helper'
require File.join(RITL_ROOT, 'db', 'migrate', '008_add_foreign_key')

RSpec.describe 'migrations' do
  let(:connection) { ActiveRecord::Base.connection }

  it 'leaves the lookup columns indexed' do
    expect(connection.index_exists?(:issue_todo_lists, :project_id)).to be(true)
    expect(connection.index_exists?(:issue_todo_list_items, :issue_id)).to be(true)
    expect(connection.index_exists?(:issue_todo_list_items, [:issue_todo_list_id, :position])).to be(true)
  end

  # On PostgreSQL a failed statement aborts the transaction, so the rescue in
  # 008 only works inside a savepoint. MySQL commits DDL right away and cannot
  # run this inside the example's transaction.
  it 'skips a foreign key that existing rows violate and adds the others' do
    skip 'PostgreSQL only' unless Redmine::Database.postgresql?

    migration = AddForeignKey.new
    migration.verbose = false
    [[:issue_todo_list_items, :issues, :issue_id], [:issue_todo_list_items, :issue_todo_lists, :issue_todo_list_id],
     [:issue_todo_lists, :users, :created_by_id], [:issue_todo_lists, :users, :last_updated_by_id]].each do |from, to, column|
      connection.remove_foreign_key(from, column: column) if connection.foreign_key_exists?(from, to, column: column)
    end
    list = create_todo_list('Orphans')
    connection.execute("INSERT INTO issue_todo_list_items (issue_todo_list_id, issue_id, position) VALUES (#{list.id}, 999999, 1)")

    expect { migration.migrate(:up) }.to output(/Could not add foreign key constraint to issue_todo_list_items for issue_id/).to_stderr
    expect(connection.foreign_key_exists?(:issue_todo_list_items, :issue_todo_lists)).to be(true)
    expect(connection.foreign_key_exists?(:issue_todo_list_items, :issues)).to be(false)
    # Added after the failing one, so only possible if the transaction survived
    expect(connection.foreign_key_exists?(:issue_todo_lists, :users, column: :created_by_id)).to be(true)
    expect(connection.foreign_key_exists?(:issue_todo_lists, :users, column: :last_updated_by_id)).to be(true)
  end
end
