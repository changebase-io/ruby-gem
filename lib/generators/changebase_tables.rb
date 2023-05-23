module Changebase
  module Generators
    class ChangebaseTablesGenerator < Rails::Generators::NamedBase

      def create_data_migration_file
        timestamp = Time.zone.now.to_s.tr('^0-9', '')[0..13]
        filepath = "db/migrate/#{timestamp}_#{file_name}.rb"

        create_file filepath, <<-FILE
        class #{class_name} < #{ActiveRecord::Migration.current_version}

          def change
            create_table :#{Rails.application.config.changebase.metadata_table}, id: false do |t|
              t.primary_key :version, :integer
              t.jsonb       :data
            end
          end

        end
        FILE
      end

    end
  end
end