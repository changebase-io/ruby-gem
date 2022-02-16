class Changebase::Railtie < Rails::Railtie

  config.changebase = ActiveSupport::OrderedOptions.new
  config.changebase.metadata_table = "changebase_metadata"
  
  initializer 'changebase.initialize' do |app|
    ActiveSupport.on_load(:active_record) do
      require 'changebase/active_record'
    end
    
    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end
    
    Changebase.metadata_table = app.config.changebase.metadata_table
  end
  
end