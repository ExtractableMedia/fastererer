# frozen_string_literal: true

module Fastererer
  module Painter
    COLOR_CODES = {
      red: 31,
      green: 32,
      magenta: 35
    }.freeze

    @disabled = false

    def self.paint(string, color)
      # Validate before short-circuit so bad color symbols surface even with --no-color/NO_COLOR.
      color_code = COLOR_CODES[color.to_sym]
      if color_code.nil?
        raise ArgumentError,
              "Color #{color} is not supported. Allowed colors are #{COLOR_CODES.keys.join(', ')}"
      end

      return string unless colorize?

      paint_with_code(string, color_code)
    end

    def self.paint_with_code(string, color_code)
      "\e[#{color_code}m#{string}\e[0m"
    end

    def self.disable!
      @disabled = true
    end

    # Re-enables colorization; production never calls this — exists so tests can reset state.
    def self.enable!
      @disabled = false
    end

    def self.colorize?
      return false unless ENV.fetch('NO_COLOR', '').empty?
      return false if @disabled

      $stdout.tty?
    end
  end
end
