
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name     'mmm-agent'
  authors  'MultiMinerManager'
  email    'contact@multiminermanager.com'
  url      'https://www.multiminermanager.com'
}

