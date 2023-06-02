module Changebase::ActiveRecord

  autoload :Helpers,    'changebase/active_record/helpers'
  autoload :Connection, 'changebase/active_record/connection'
  
  extend ActiveSupport::Concern

  class_methods do
    def with_metadata(metadata, &block)
      connection.with_metadata(metadata, &block)
    end
  end

  def with_metadata(metadata, &block)
    self.class.with_metadata(metadata, &block)
  end
  
end