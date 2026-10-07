# frozen_string_literal: true

require_relative 'spec_helper'

# Other GEOxyz plugins patch the same core methods, most with prepend, and
# they load before this one (plugins load in alphabetical order). An
# alias_method chain set up after such a prepend aliases the prepended
# method and recurses until the stack runs out: Project > Settings and the
# issue list answered HTTP 500 with all GEOxyz plugins installed.
RSpec.describe 'patches of core methods' do
  let(:patches) { File.join(RITL_ROOT, 'lib', 'redmine_issue_todo_lists', 'patches') }

  # What another plugin does: prepend a module whose methods call super.
  let(:other_query_plugin) do
    Module.new do
      def initialize_available_filters
        super
      end

      def available_columns
        super
      end

      def joins_for_order_statement(order_options)
        super
      end
    end
  end

  let(:other_helper_plugin) do
    Module.new do
      def column_content(column, item)
        super
      end
    end
  end

  before do
    IssueQuery.prepend(other_query_plugin)
    QueriesHelper.prepend(other_helper_plugin)
    # This plugin's patches applied after the other plugin's, as at boot.
    load File.join(patches, 'issue_query_patch.rb')
    load File.join(patches, 'queries_helper_patch.rb')
    enable_todo_lists(Project.find(1))
    add_to_todo_list(create_todo_list('Sprint'), Issue.find(1))
    User.current = User.find(1)
  end

  it 'patches by prepend, without alias chains' do
    expect(IssueQuery.ancestors).to include(RedmineIssueTodoLists::Patches::IssueQueryPatch)
    expect(QueriesHelper.ancestors).to include(RedmineIssueTodoLists::Patches::QueriesHelperPatch)
    expect(IssueQuery.instance_methods.grep(/_itdl\z/)).to eq([])
    expect(QueriesHelper.instance_methods.grep(/_itdl\z/)).to eq([])
  end

  it 'keeps filters, columns and sorting working next to another plugin' do
    query = IssueQuery.new(:name => '_', :project => Project.find(1))
    expect(query.available_filters).to include('todo_lists_ids')
    expect(query.available_columns.map(&:name)).to include(:'issue_todo_list_titles.titles',
                                                           :'issue_todo_list_item_orders.positions')
    query.sort_criteria = [['issue_todo_list_item_orders.positions', 'asc']]
    expect(query.issues.map(&:id)).to include(1)
  end

  it 'keeps the issue list with the list titles column working next to another plugin' do
    session = new_session
    login(session, 'jsmith')
    session.get '/projects/ecookbook/issues?set_filter=1&c[]=subject&c[]=issue_todo_list_titles.titles' \
                '&c[]=issue_todo_list_item_orders.positions&sort=issue_todo_list_item_orders.positions'
    expect(session.response.status).to eq(200)
    cell = Nokogiri::HTML(session.response.body).at_css('tr#issue-1 td.issue_todo_list_titles-titles')
    expect(cell.at_css('a').text).to eq('Sprint')
  end
end
