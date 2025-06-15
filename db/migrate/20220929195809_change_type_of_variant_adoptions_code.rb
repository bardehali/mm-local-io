class ChangeTypeOfVariantAdoptionsCode < ActiveRecord::Migration[6.0]
  def up
    change_column Spree::VariantAdoption.table_name, :code, :binary, limit: 32

    Spree::VariantAdoption.where('code is not null').update_all(code: nil)
  end

  def down
    change_column Spree::VariantAdoption.table_name, :code, :string, limit: 32
  end
end
