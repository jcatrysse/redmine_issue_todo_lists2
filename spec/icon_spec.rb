# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe RedmineIssueTodoLists::Icon do
  # Answers to sprite_icon, like a view on Redmine 6, or on 5.1 with a plugin
  # that defines a sprite_icon of its own.
  let(:view) do
    Class.new do
      def sprite_icon(name, label = nil, icon_only: false)
        "<svg #{name}#{' icon-only' if icon_only}>#{label}"
      end
    end.new
  end

  # Core's own helpers, not ApplicationHelper: another plugin can add one.
  it 'uses sprites exactly where core has sprite_icon' do
    helpers = Dir[Rails.root.join('app', 'helpers', '*.rb')]
    defined_by_core = helpers.any? { |f| File.read(f).include?('def sprite_icon') }
    expect(described_class.sprites?).to eq(defined_by_core)
  end

  it 'draws from the sprite from Redmine 6 on and gives the label alone before' do
    if Redmine::VERSION::MAJOR >= 6
      expect(described_class.call(view, 'add', 'Add')).to eq('<svg add>Add')
      expect(described_class.call(view, 'edit', 'Edit', icon_only: true)).to eq('<svg edit icon-only>Edit')
    else
      expect(described_class.call(view, 'add', 'Add')).to eq('Add')
      expect(described_class.call(view, 'edit', 'Edit', icon_only: true)).to eq('Edit')
    end
  end
end
