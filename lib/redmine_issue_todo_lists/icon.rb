# frozen_string_literal: true

module RedmineIssueTodoLists
  # Redmine 6 and later draw icons from an SVG sprite. Redmine 5.1 shows them
  # through the CSS class of the link, so there the label is all that is needed.
  # Decided by version, not by respond_to?(:sprite_icon): another plugin can
  # define a sprite_icon of its own on 5.1, where core's CSS has no place for it.
  module Icon
    def self.sprites?
      Redmine::VERSION::MAJOR >= 6
    end

    def self.call(view, name, label, icon_only: false)
      return label unless sprites?

      view.sprite_icon(name, label, icon_only: icon_only)
    end
  end
end
