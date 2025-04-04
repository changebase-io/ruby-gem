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
      elsif app.respond_to?(:secrets) && app.secrets.changebase && app.secrets.changebase.is_a?(String) #TODO: remove when dropping support for rails < 8.0
        app.secrets.changebase
      elsif File.exist?(Rails.root.join('config', 'changebase.yml'))
        app.config_for(:changebase)[:api_key]
      end
      
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
    end

    ActiveSupport.on_load(:action_controller) do
      require 'changebase/action_controller'
    end

    Changebase.configure(**app.config.changebase.to_h)
  end

end