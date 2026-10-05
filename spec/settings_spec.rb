# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'plugin settings' do
  let(:session) { new_session }
  let(:remaining_keys) { %w[show_in_issue_sidebar show_in_issue_edit] }

  before { login(session, 'admin') }

  def settings_page
    session.get '/settings/plugin/redmine_issue_todo_lists2'
    expect(session.response.status).to eq(200)
    session.response.body
  end

  def checkbox(body, key)
    body[/<input[^>]*id="settings_#{key}"[^>]*>/]
  end

  it 'defaults to the two remaining settings only' do
    expect(plugin.settings[:default].keys).to eq(remaining_keys)
  end

  it 'renders the two remaining checkboxes and not the removed one' do
    body = settings_page

    expect(body.scan(/name="settings\[([^\]]+)\]"/).flatten).to eq(remaining_keys)
    expect(body).not_to include('enable_dates_context_menu')
    expect(body).not_to include('translation missing')
    expect(body).to include(I18n.t(:label_general_issue_todo_lists_settings))
  end

  it 'renders the same with the removed setting still stored from 2.2.x' do
    Setting.plugin_redmine_issue_todo_lists2 = {
      'enable_dates_context_menu' => '1', 'show_in_issue_sidebar' => '1', 'show_in_issue_edit' => '1'
    }
    body = settings_page

    expect(body.scan(/name="settings\[([^\]]+)\]"/).flatten).to eq(remaining_keys)
    expect(body).not_to include('enable_dates_context_menu')
    remaining_keys.each { |key| expect(checkbox(body, key)).to include('checked') }
  end

  it 'saves, drops the removed setting and reloads what was saved' do
    Setting.plugin_redmine_issue_todo_lists2 = {
      'enable_dates_context_menu' => '1', 'show_in_issue_sidebar' => '1', 'show_in_issue_edit' => '1'
    }

    # An unticked box is not posted, as in a browser.
    session.post '/settings/plugin/redmine_issue_todo_lists2',
                 :params => {:settings => {'show_in_issue_sidebar' => '1'}}
    expect(session.response.status).to eq(302)

    Setting.clear_cache
    expect(Setting.plugin_redmine_issue_todo_lists2.to_h).to eq('show_in_issue_sidebar' => '1')

    body = settings_page
    expect(checkbox(body, 'show_in_issue_sidebar')).to include('checked')
    expect(checkbox(body, 'show_in_issue_edit')).not_to include('checked')
  end

  it 'renders in the user\'s language' do
    User.find(1).update_columns(:language => 'nl')
    body = settings_page

    expect(body).to include(ERB::Util.html_escape(I18n.t(:label_general_issue_todo_lists_settings, :locale => :nl)))
    remaining_keys.each do |key|
      expect(body).to include(ERB::Util.html_escape(I18n.t(:"label_#{key}", :locale => :nl)))
    end
    expect(body).not_to include('translation missing')
  end
end
