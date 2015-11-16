require 'yaml'

module Settings
  # again - it's a singleton, thus implemented as a self-extended module
  extend self

  # This is the main point of entry - we call Settings.load! and provide
  # a name of the file to read as it's argument. We can also pass in some
  # options, but at the moment it's being used to allow per-environment
  # overrides in Rails
  def load!(filename)
    @config = YAML::load_file(filename)
  end

  def get(key)
    @config[key]
  end

end
