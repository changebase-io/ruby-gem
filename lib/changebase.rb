module Changebase
  autoload :ActiveRecord, 'changebase/active_record'
  autoload :ActionController, 'changebase/action_controller'
end

require 'changebase/railtie' if defined?(Rails)