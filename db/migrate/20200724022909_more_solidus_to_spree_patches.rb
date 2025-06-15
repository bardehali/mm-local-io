class MoreSolidusToSpreePatches < ActiveRecord::Migration[6.0]
  def change
    add_column_unless_exists :spree_variants, :discontinue_on, :datetime
    add_index_unless_exists :spree_variants, :discontinue_on
  end
end
