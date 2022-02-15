class Changebase::Railtie < Rails::Railtie
  
  initializer 'changebase.initialize' do
    ActiveSupport.on_load(:active_record) do
      require 'changebase/active_record'
    end
    
    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end
  end
  
end