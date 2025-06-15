class CreateRecordStats < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_record_stats do |t|
      t.string  :record_type, limit: 128, nil: false
      t.string  :record_column, limit: 64, default: 'id'
      t.integer :record_id
      t.integer :record_count, default: 0
      t.timestamps

      t.index [:record_type, :record_column], name: 'idx_record_type_id'
      t.index [:record_type, :record_column, :record_count], name: 'idx_record_type_column_count'
    end

    begin
      puts "Counting for Spree::Classification"
      ::Spree::RecordStat.save_group_counts_for('Spree::Classification', 'taxon_id')
    rescue; end
  end

  def down
    drop_table_if_exists :spree_record_stats
  end
end
