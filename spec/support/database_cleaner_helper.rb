# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) { DatabaseCleaner.clean_with(:truncation) }

  config.before(:each) { DatabaseCleaner.strategy = :truncation }

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :truncation, { pre_count: true }
  end

  config.before(:each) { DatabaseCleaner.start }

  config.after(:each) { DatabaseCleaner.clean }
end
