require_relative "lib/payu/version"

Gem::Specification.new do |s|
  s.name        = "payu-ruby"
  s.version     = Payu::VERSION
  s.summary     = "Ruby client for PayU India payment gateway"
  s.description = "Hash generation, payment initiation params, server-to-server verification, and refund support for PayU India. Framework-agnostic — works with Rails, Sinatra, or plain Ruby."
  s.authors     = ["Vishwajeetsingh Desurkar"]
  s.email       = ["vishwajeetsinghd@gmail.com"]
  s.homepage    = "https://github.com/Selectus2/payu-rb"
  s.license     = "MIT"

  s.files         = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.1"

  s.add_development_dependency "rspec",   "~> 3.13"
  s.add_development_dependency "webmock", "~> 3.23"
end
