class CreateSearchableRecordOptionTypes < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_searchable_record_option_types do |t|
      t.string  :record_type, limit: 128, null: false
      t.integer :record_id, null: false
      t.integer :option_type_id, null: false
      t.integer :position, default: 0
      t.index [:record_type, :record_id], name: 'idx_searchable_ot_record'
      t.index :position, name: 'idx_searchable_record_ot_position'
    end

    puts "Copy over #{Spree::RelatedOptionType.count} RelatedOptionType to Searchable"
    Spree::RelatedOptionType.all.each do|related_ot|
      Spree::SearchableRecordOptionType.find_or_create_by(
        record_type: 'Spree::Taxon', record_id: related_ot.record_id, 
        option_type_id: related_ot.option_type_id
      ) do|searchable|
        searchable.position = related_ot.position
      end
    end
  end

  def down
    drop_table_if_exists :spree_searchable_record_option_types
  end
end
