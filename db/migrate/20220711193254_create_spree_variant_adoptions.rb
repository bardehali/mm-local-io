class CreateSpreeVariantAdoptions < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_variant_adoptions do |t|
      t.integer :variant_id
      t.integer :user_id
      t.boolean :preferred_variant, default: false
      t.timestamps

      t.index :variant_id
      t.index [:variant_id, :preferred_variant], name:'idx_spree_variant_adoptions_variant_pref'
      t.index :user_id
    end

    create_table_unless_exists :spree_adoption_prices do |t|
      t.integer :variant_adoption_id
      t.float   :amount
      t.string  :currency, limit: 255
      t.string  :country_iso, limit: 16
      t.float   :compare_at_amount
      t.timestamps

      t.index :variant_adoption_id
    end
    add_column_unless_exists Spree::Variant.table_name, :converted_to_variant_adoption, :boolean, default: false
    add_index_unless_exists Spree::Variant.table_name, [:converted_to_variant_adoption, :deleted_at], name: 'idx_variants_converted_deleted'

    add_column_unless_exists Spree::LineItem.table_name, :variant_adoption_id, :integer
  end

  def down
    remove_index_if_exists Spree::Variant.table_name, [:converted_to_variant_adoption, :deleted_at]
    remove_column_if_exists Spree::Variant.table_name, :converted_to_variant_adoption
    remove_column_if_exists Spree::LineItem.table_name, :variant_adoption_id
    drop_table_if_exists :spree_variant_adoption_prices
    drop_table_if_exists :spree_variant_adoptions
  end
end
