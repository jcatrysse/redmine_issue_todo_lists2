# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'plugin registration' do
  it 'is registered as version 2.4.0' do
    expect(plugin.version).to eq('2.4.0')
  end

  it 'documents the registered version on top of the changelog and the compatibility list' do
    changelog = File.read(File.join(RITL_ROOT, 'CHANGELOG.md'))
    readme = File.read(File.join(RITL_ROOT, 'README.md'))

    expect(changelog[/^### (\S+)/, 1]).to eq(plugin.version)
    expect(readme[/^## Compatibility\n\* Version (\S+)/, 1]).to eq(plugin.version)
  end

  # The Dates context menu moved to redmine_context_menu_actions in 2.3.0.
  it 'leaves nothing of the Dates context menu behind' do
    files = Dir[File.join(RITL_ROOT, '{app,lib,config,assets}', '**', '*')].select { |f| File.file?(f) }
    files << File.join(RITL_ROOT, 'init.rb')
    leftovers = /enable_dates_context_menu|field_dates|update-dates-modal|data-disables/

    # binread: an image under assets must not break the scan.
    expect(files.select { |f| File.binread(f).match?(leftovers) }).to eq([])
  end

  it 'adds no script to the issues context menu' do
    partial = File.read(File.join(RITL_ROOT, 'app/views/context_menus/issue_todo_lists/_issues_context_menu.html.erb'))

    expect(partial).not_to match(/javascript_tag|<script/)
  end
end
