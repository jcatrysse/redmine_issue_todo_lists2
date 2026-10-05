# frozen_string_literal: true

require_relative 'spec_helper'

RITL_LOCALES_PATH = File.join(RITL_ROOT, 'config', 'locales')
RITL_REFERENCE_KEYS = YAML.load_file(File.join(RITL_LOCALES_PATH, 'en.yml'))['en'].keys.sort.freeze
# Only used by the Dates context menu, removed in 2.3.0.
RITL_REMOVED_KEYS = %w[field_dates label_enable_dates_context_menu].freeze

RSpec.describe 'translations' do
  it 'has the six shipped locales' do
    expect(Dir[File.join(RITL_LOCALES_PATH, '*.yml')].map { |f| File.basename(f, '.yml') }.sort)
      .to eq(%w[de en es fr nl zh])
  end

  Dir[File.join(RITL_LOCALES_PATH, '*.yml')].sort.each do |path|
    locale = File.basename(path, '.yml')

    describe locale do
      let(:translations) { YAML.load_file(path)[locale] }

      it 'is keyed by its own locale' do
        expect(translations).to be_a(Hash)
      end

      it 'covers exactly the keys of the English reference' do
        expect(translations.keys.sort).to eq(RITL_REFERENCE_KEYS)
      end

      it 'has no blank value' do
        expect(translations.reject { |_, v| v.to_s.strip.present? }).to be_empty
      end

      it 'no longer has the keys of the Dates context menu' do
        expect(translations.keys & RITL_REMOVED_KEYS).to eq([])
      end

      it 'labels every setting' do
        labels = plugin.settings[:default].keys.map { |key| "label_#{key}" }

        expect(labels - translations.keys).to eq([])
      end
    end
  end
end
