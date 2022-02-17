class Changebase::Engine < ::Rails::Engine

  config.changebase = ActiveSupport::OrderedOptions.new
  config.changebase.metadata_table = "changebase_metadata"
  
  initializer :changebase do |app|
    migration_paths = config.paths['db/migrate'].expanded
    
    ActiveSupport.on_load(:active_record) do
      require 'changebase/active_record'
      migration_paths.each do |path|
        ActiveRecord::Tasks::DatabaseTasks.migrations_paths << path
      end
    end
    
    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end
    
    Changebase.metadata_table = app.config.changebase.metadata_table
  end
  
end