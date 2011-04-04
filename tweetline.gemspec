Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "tweetline"
  s.version = "0.0.1"
  s.summary = "Command line client for Twitter."
  s.description = "Tweetline is a command line Twitter client for those who can't imagine a better interface to anything than the command line.  Also, some folks may find it useful for automating some Twitter interactions."

  s.required_ruby_version = ">= 1.8.7"
  s.required_rubygems_version = ">= 1.3.6"

  s.author = "Anthony Crumley"
  s.email = "anthony.crumley@gmail.com"
  s.homepage = "https://github.com/craftycode/tweetline"
  s.rubyforge_project = "tweetline"

  s.bindir = "bin"
  s.executables = ["tl"]
  s.default_executable = = "tl"

  s.add_dependency('twitter', '~> 1.2.0')
  s.add_dependency('json', '~> 1.5.1')
end
