# frozen_string_literal: true

require 'bundler/setup'

ENV['RACK_ENV'] = 'test'
require 'dotenv'
Dotenv.load('.env.test')

require 'byebug'
require 'dataflow/embulk'

PostgresqlTestClient = Sequel.connect("postgresql://#{ENV['MOJACO_POSTGRESQL_USER']}:#{ENV['MOJACO_POSTGRESQL_PASSWORD']}@localhost/dataflow_test")

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Mongoid::Clients.default.database.drop

    [PostgresqlTestClient].each do |sql_client|
      sql_client.disconnect

      sql_client.tables.each do |table|
        sql_client.drop_table(table)
      end
    end
  end
end
