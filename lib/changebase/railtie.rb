class Changebase::Engine < ::Rails::Engine

  config.changebase = ActiveSupport::OrderedOptions.new
  # config.changebase.mode = nil
  config.changebase.metadata_mode   = "message"
  config.changebase.metadata_table  = "changebase_metadata"

  initializer :changebase do |app|
    ActiveSupport.on_load(:active_record) do
      Changebase.logger = ActiveRecord::Base.logger

      case Changebase.mode
      when 'replication'
        Changebase::Replication.load! if !Changebase::Replication.loaded?
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
