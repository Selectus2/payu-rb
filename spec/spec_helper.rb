require "payu"
require "webmock/rspec"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
