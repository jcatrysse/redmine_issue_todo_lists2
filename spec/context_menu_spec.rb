# frozen_string_literal: true

require_relative 'spec_helper'

# The issues context menu gets the to-do lists submenu from the
# view_issues_context_menu_end hook. Up to 2.2.2 the same partial also rendered
# a "Dates" entry with a hidden modal and a script; that moved to
# redmine_context_menu_actions in 2.3.0.
RSpec.describe 'issues context menu' do
  let(:session) { new_session }
  let(:project) { Project.find(1) }
  let(:issue1)  { Issue.find(1) }
  let(:issue2)  { Issue.find(2) }

  def context_menu(*issues)
    session.post '/issues/context_menu', :params => {:ids => issues.map(&:id), :back_url => '/issues'}
    expect(session.response.status).to eq(200)
    session.response.body
  end

  # The entries of the to-do lists submenu, or nil when there is no submenu.
  def todo_list_entries(body)
    folder = Nokogiri::HTML.fragment(body).css('li.folder').find do |li|
      li.at_css('> a.submenu')&.text&.strip == I18n.t(:issue_todo_lists_title)
    end
    return nil unless folder

    folder.css('> ul > li').map do |li|
      link = li.at_css('> a')
      uri = URI.parse(link['href'])
      {
        :title => li['title'], :text => link.text.strip, :class => link['class'],
        :method => link['data-method'], :path => uri.path,
        :query => Rack::Utils.parse_nested_query(uri.query)
      }
    end
  end

  def allocate_path(todo_list)
    "/projects/#{todo_list.project.identifier}/issue_todo_lists/#{todo_list.id}/bulk_allocate_issues"
  end

  # The hook output sits right before the closing </ul> of the menu. With no
  # to-do lists it must add nothing, not even an empty <li>.
  def ends_with_core_entry?(body)
    body.match?(%r{</li>\s*</ul>\s*\z})
  end

  describe 'Dates entry, removed in 2.3.0' do
    before do
      # The upgrade path: 2.2.x stored the setting and nothing deletes it.
      Setting.plugin_redmine_issue_todo_lists2 = {
        'enable_dates_context_menu' => '1', 'show_in_issue_sidebar' => '1', 'show_in_issue_edit' => '1'
      }
      login(session, 'admin')
    end

    {'a single issue' => [1], 'several issues' => [1, 2]}.each do |label, ids|
      it "is not rendered for #{label}, even with the old setting stored as 1" do
        expect(Setting.plugin_redmine_issue_todo_lists2['enable_dates_context_menu']).to eq('1')
        body = context_menu(*Issue.where(:id => ids).to_a)
        anchors = Nokogiri::HTML.fragment(body).css('a').map { |a| a.text.strip }

        expect(anchors).not_to include('Dates')
        expect(body).not_to include('update-dates-modal')
        expect(body).not_to include('data-disables')
        expect(body).not_to include('issue[start_date]')
        expect(body).not_to include('issue[due_date]')
        expect(ends_with_core_entry?(body)).to be(true), 'the hook left markup after the core entries'
      end
    end
  end

  describe 'to-do lists submenu' do
    let!(:both)       { create_todo_list('A both') }
    let!(:none)       { create_todo_list('B none') }
    let!(:first_only) { create_todo_list('C first only') }

    before do
      add_to_todo_list(both, issue1, issue2)
      add_to_todo_list(first_only, issue1)
      login(session, 'admin')
    end

    it 'offers add and unlist for a single issue' do
      entries = todo_list_entries(context_menu(issue1))
      prefix = "#{project.name} - "

      expect(entries.map { |e| e[:text] }).to eq(['A both', 'B none', 'C first only'])
      expect(entries.map { |e| e[:title] }).to eq(["#{prefix}A both: unlist item", "#{prefix}B none: add item",
                                                   "#{prefix}C first only: unlist item"])
      expect(entries.map { |e| e[:class] }).to eq(['icon icon-del', 'icon icon-add', 'icon icon-del'])
      expect(entries.map { |e| e[:query]['list_count'] }).to eq(['-1', '1', '-1'])
      expect(entries.map { |e| e[:path] }).to eq([both, none, first_only].map { |l| allocate_path(l) })
      entries.each do |entry|
        expect(entry[:method]).to eq('post')
        expect(entry[:query]['issue_ids']).to eq(['1'])
        expect(entry[:query]['back_url']).to eq('/issues')
      end
    end

    it 'offers unlist all, add all and a partial add for several issues' do
      entries = todo_list_entries(context_menu(issue1, issue2))
      prefix = "#{project.name} - "

      expect(entries.map { |e| e[:title] }).to eq(["#{prefix}A both: unlist all items", "#{prefix}B none: add all items",
                                                   "#{prefix}C first only: add 1 items from 2"])
      expect(entries.map { |e| e[:class] }).to eq(['icon icon-del', 'icon icon-add', 'icon icon-warning'])
      expect(entries.map { |e| e[:query]['list_count'] }).to eq(['-2', '2', '1'])
      entries.each { |entry| expect(entry[:query]['issue_ids']).to eq(['1', '2']) }
    end

    it 'is the last entry of the menu' do
      body = context_menu(issue1)

      expect(Nokogiri::HTML.fragment(body).at_css('ul > li:last-child > a.submenu')&.text&.strip)
        .to eq(I18n.t(:issue_todo_lists_title))
    end
  end

  describe 'for a project member' do
    let(:role) { Role.find(1) } # jsmith is Manager of project 1 in the core fixtures

    before do
      expect(User.find_by_login('jsmith').roles_for_project(project)).to include(role)
      create_todo_list('Sprint')
      login(session, 'jsmith')
    end

    it 'shows the submenu with the permission and the module enabled' do
      project.enable_module!(:issue_todo_lists)
      role.add_permission!(:add_issue_todo_list_items_context_menu)

      expect(todo_list_entries(context_menu(issue1)).map { |e| e[:text] }).to eq(['Sprint'])
      expect(todo_list_entries(context_menu(issue1, issue2)).map { |e| e[:text] }).to eq(['Sprint'])
    end

    it 'shows no submenu without the permission' do
      project.enable_module!(:issue_todo_lists)
      role.remove_permission!(:add_issue_todo_list_items_context_menu)

      body = context_menu(issue1)
      expect(todo_list_entries(body)).to be_nil
      expect(ends_with_core_entry?(body)).to be(true)
    end

    it 'shows no submenu when the module is disabled' do
      project.disable_module!(:issue_todo_lists)
      role.add_permission!(:add_issue_todo_list_items_context_menu)

      body = context_menu(issue1, issue2)
      expect(todo_list_entries(body)).to be_nil
      expect(ends_with_core_entry?(body)).to be(true)
    end
  end

  describe 'without any to-do list' do
    before { login(session, 'admin') }

    it 'renders the core menu for a single issue and adds nothing' do
      expect(IssueTodoList.count).to eq(0)
      body = context_menu(issue1)

      expect(todo_list_entries(body)).to be_nil
      expect(ends_with_core_entry?(body)).to be(true)
    end

    it 'renders the core menu for several issues and adds nothing' do
      body = context_menu(issue1, issue2)

      expect(todo_list_entries(body)).to be_nil
      expect(ends_with_core_entry?(body)).to be(true)
    end
  end
end
