class Changebase::Engine < ::Rails::Engine

  config.changebase = ActiveSupport::OrderedOptions.new
  config.changebase.mode = "replication"
  config.changebase.metadata_table = "changebase_metadata"
  
  initializer :changebase do |app|
    migration_paths = config.paths['db/migrate'].expanded
    
    ActiveSupport.on_load(:active_record) do
      case Changebase.mode
      when 'replication'
        Changebase::Replication.load! if !Changebase::Replication.loaded?
        migration_paths.each do |path|
          ActiveRecord::Tasks::DatabaseTasks.migrations_paths << path
        end
      when 'inline'
        Changebase::Inline.load! if !Changebase::Inline.loaded?
      end
    end
    
    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end
    
    Changebase.configure(**app.config.changebase.to_h)
  end
  
end