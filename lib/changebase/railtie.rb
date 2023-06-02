class Changebase::Engine < ::Rails::Engine

  config.changebase = ActiveSupport::OrderedOptions.new
  config.changebase.api_key  = nil
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
      
      api_key_or_url = if app.config.changebase.api_key
        app.config.changebase.api_key
      elsif app.credentials.changebase && app.credentials.changebase.is_a?(String)
        app.credentials.changebase
      elsif app.secrets.changebase && app.secrets.changebase.is_a?(String)
        app.secrets.changebase
      elsif app.config_for(:changebase)
        app.config_for(:changebase)[:api_key]
      end
      
      puts api_key_or_url.inspect
      configs = if api_key_or_url =~ /\A\w+:/
        h = ActiveRecord::DatabaseConfigurations::ConnectionUrlResolver.new(api_key_or_url).to_hash.symbolize_keys
        h[:api_key] = h.delete(:username)
        if h[:adapter] != 'sunstone'
          h[:use_ssl] = h[:adapter] == 'https'
          h[:adapter] = 'sunstone'
        end
        h
      elsif api_key_or_url
        {adapter: 'sunstone', port: 443, api_key: api_key_or_url, host: 'changebase.io', use_ssl: true}
      end
      
      if configs
        require 'sunstone'
        require 'arel/extensions'
        Changebase::Record.establish_connection(configs)
      end
      
      ActiveSupport.on_load(:after_initialize) do
        if defined?(::ApplicationRecord)
          ::ApplicationRecord.include(Changebase::ActiveRecord::Helpers)
        end
      end
    end

    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end

    Changebase.configure(**app.config.changebase.to_h)
  end

end