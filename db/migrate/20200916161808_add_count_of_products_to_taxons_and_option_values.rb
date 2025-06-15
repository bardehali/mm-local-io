class AddCountOfProductsToTaxonsAndOptionValues < ActiveRecord::Migration[6.0]
  def up

    puts "Categories =========================="
    category_taxonomy = Spree::Taxonomy.find_or_create_by(name: 'Categories')
    Spree::Taxon.find_or_create_by(name:'Categories', taxonomy_id: category_taxonomy.id) do|taxon|
      taxon.depth = 0
      taxon.position = 0
    end
    s = ''
    Spree::CategoryTaxon.root.descendants.each do|t| 
      cnt = Spree::Classification.where(taxon_id: t.self_and_descendants.collect(&:id) ).count;
      stat = Spree::RecordStat.find_or_initialize_by(
        record_type: 'Spree::Classification', record_column: 'taxon_id', record_id: t.id)
      stat.record_count = cnt
      stat.save
      s << "%80s | %4d\n" % [t.breadcrumb, cnt] if cnt > 0
    end
    puts s

    puts "Brands =================================="
    s2 = ''
    brand = Spree::OptionType.find_by_name 'brand'
    brand.option_values.each do|ov| 
      cnt = Spree::OptionValueVariant.joins(:variant).where(option_value_id: ov.id, Spree::Variant.table_name.to_sym => { is_master: true } ).count
      stat = Spree::RecordStat.find_or_initialize_by(
        record_type: 'Spree::OptionValueVariant', record_column: 'option_value_id', record_id: ov.id)
      stat.record_count = cnt
      stat.save
      s2 << "%40s | %4d\n" % [ov.presentation, cnt] if cnt > 0 
    end
    puts s2
  end

  def down
  end
end
