
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name     'mmm-agent'
  authors  'MyMiners'
  email    'contact@myminers.net'
  url      'https://myminers.net'
}

