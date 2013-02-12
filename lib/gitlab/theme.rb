module Gitlab
  class Theme
    def self.css_class_by_id(id)
      themes = {
        1 => "ui_basic",
        2 => "ui_mars",
        3 => "ui_modern",
        4 => "ui_gray",
        5 => "ui_color",
	6 => "ui_bb"
      }

      id ||= 6 

      return themes[id]
    end
  end
end
