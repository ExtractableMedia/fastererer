# frozen_string_literal: true

module EnvHelper
  def with_env(key, value)
    original = ENV.fetch(key, nil)
    set_env(key, value)
    yield
  ensure
    set_env(key, original)
  end

  private

  def set_env(key, value)
    return ENV.delete(key) if value.nil?

    ENV[key] = value
  end
end
