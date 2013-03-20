module Gitlab
  class Theme
    def self.css_class_by_id(id)
      themes = {
        1 => "ui_bb",
        2 => "ui_basic",
        3 => "ui_mars",
        4 => "ui_modern",
        5 => "ui_gray",
        6 => "ui_color"
      }
      id ||= 1
      return themes[id]
    end
  end
end
