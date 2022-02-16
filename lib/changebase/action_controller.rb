module Changebase::ActionController
  extend ActiveSupport::Concern

  included do
    prepend_around_action :changebase_metadata_wrapper
  end
  
  module ClassMethods
    def changebase(*keys, &block)
      method = if block
        block
      elsif keys.size > 1
        keys.pop
      else
        keys.first
      end
      
      @changebase_metadata ||= []
      @changebase_metadata << [keys, method]
    end
    
    def changebase_metadata
      if self.superclass.respond_to?(:changebase_metadata)
        (@changebase_metadata || []) + self.superclass.changebase_metadata
      else
        @changebase_metadata || []
      end
    end
  end
  
  def changebase_metadata
    self.class.changebase_metadata
  end
    
  def changebase_metadata_wrapper(&block)
    metadata = {}
    
    changebase_metadata.each do |keys, value|
      data = metadata
      keys[0...-1].each do |key|
        data[key] ||= {}
        data = data[key]
      end
      
      value = case value
      when Symbol
        self.send(value)
      when Proc
        instance_exec(&value)
      else
        value
      end
      
      if keys.last
        data[keys.last] ||= value
      else
        data.merge!(value)
      end
    end

    ActiveRecord::Base.with_metadata(metadata, &block)
  end
  
end

ActionController::Base.include(Changebase::ActionController)