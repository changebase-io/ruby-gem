require 'rails/generators/active_record'

module Changebase
  module Generators
    class ChangebaseTablesGenerator < ::ActiveRecord::Generators::Base
      desc "Generate a migration for the Changebase metadata table"
      
      argument :table_name, type: :string, default: "changebase_metadata", banner: "changebase_metadata"
      
      source_root File.expand_path("../templates", __FILE__)
      
      def create_data_migration_file
        timestamp = Time.now.to_s.tr('^0-9', '')[0..13]
        filepath = "db/migrate/#{timestamp}_create_changebase_tables.rb"

        migration_template "migration.rb", "#{db_migrate_path}/create_changebase_tables.rb", {
          migration_version: migration_version,
          table_name: 
        }
      end
      
      def table_name
        return options[:table_name] if options[:table_name]
        
        
        return Rails.application.config.changebase.metadata_table if Rails.application&.respond_to?(:changebase)
        
        "changebase_metadata"
      end
      
      def migration_version
        "#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}"
      end

    end
  end
end