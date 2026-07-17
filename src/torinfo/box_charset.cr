module Torinfo
  # Which glyphs the `--box` format draws its borders with.
  enum BoxCharset
    # Choose UTF-8 or ASCII from the locale environment.
    Auto
    Utf8
    Ascii

    # Resolves Auto against a locale string (from LC_ALL/LC_CTYPE/LANG); a
    # concrete Utf8/Ascii resolves to itself.
    def resolve(locale : String?) : BoxCharset
      return self unless auto?
      (locale || "").downcase.matches?(/utf-?8/) ? Utf8 : Ascii
    end

    # The locale string that drives Auto detection: LC_ALL, then LC_CTYPE, then
    # LANG, then empty.
    def self.env_locale(env = ENV) : String
      env["LC_ALL"]? || env["LC_CTYPE"]? || env["LANG"]? || ""
    end
  end
end
