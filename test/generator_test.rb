require "test_helper"
require "rails/generators/test_case"

class GeneratorTest < Rails::Generators::TestCase
  tests Changebase::Generators::ChangebaseTablesGenerator
  destination File.expand_path("../tmp", __dir__)
  setup :prepare_destination
  
  def test_should_add_migration
    run_generator ['changebase_tables']

    assert_migration "db/migrate/create_changebase_tables.rb" do |content|
      assert_match(/create_table :changebase_metadata/, content)
    end
  end
  
  def test_should_add_migration_with_custom_table
    run_generator ['changebase_tables', '--table_name=mytable']

    assert_migration "db/migrate/create_changebase_tables.rb" do |content|
      assert_match(/create_table :changebase_metadata/, content)
    end
  end

end