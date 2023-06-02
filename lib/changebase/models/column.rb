class Changebase::Column < Changebase::Record
  self.table_name = "columns"
  self.inheritance_column = nil
  
  alias_attribute :was, :previous_value

  # belongs_to :integration
  belongs_to :event#, inverse_of: :columns
end