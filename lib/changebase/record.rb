module Changebase
  class Record < ::ActiveRecord::Base

    self.abstract_class = true
    self.connection_class = true

  end
end
