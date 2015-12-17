require 'yaml'

module Settings
  # Singleton class
  extend self

  def load!(filename)
    @config = YAML::load_file(filename)
  end

  def get(key)
    @config[key]
  end

end
