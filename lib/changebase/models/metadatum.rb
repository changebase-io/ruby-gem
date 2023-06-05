class Changebase::Metadatum < Changebase::Record
  self.table_name = "metadata"
  self.inheritance_column = nil

  belongs_to :integration
  # belongs_to :event#, inverse_of: :columns
  
  belongs_to :transaxtion, class_name: "Transaction", foreign_key: :transaction_id
  
  def value
    JSON.parse(read_attribute("value"))
  end
  
end