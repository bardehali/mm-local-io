class CreateSpreeRelatedOptionTypes < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_related_option_types do |t|
      t.string :record_type, limit: 128, null: false
      t.integer :record_id
      t.integer :option_type_id
      t.integer :position, default: 1
      t.index [:record_type, :record_id], name: 'idx_spree_rot_record_type_id'
      t.index :position, name: 'idx_spree_rot_position'
    end
  end

  def down
    drop_table_if_exists :spree_related_option_types
  end
end
