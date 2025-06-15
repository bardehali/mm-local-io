class PopulateFromIofferRecords < ActiveRecord::Migration[6.0]
  def up
    puts "Payment methods .."
    Ioffer::PaymentMethod.all.each do|pm|
      puts "#{pm.name}: #{pm.display_name}"
      payment_method = Spree::PaymentMethod.find_or_create_by(name: pm.name) do|p|
        p.description = "Pay with #{pm.display_name}"
        p.available_to_users = true
        p.available_to_admin = true
      end
    end

    puts 'Categories ..'

    create_table_unless_exists :category_to_taxons do|t|
      t.integer :category_id
      t.integer :taxon_id
      t.index :category_id
    end

    categories_t = Spree::Taxonomy.where(name:'categories').first
    ioffer_to_shoppn_mapping = Ioffer::Category::TO_SHOPPN_CATEGORIES_MAPPING
    s = ''
    Ioffer::Category.all.each do|ioffer_cat|
      list = ioffer_to_shoppn_mapping[ioffer_cat.name]
      list.each do|cat_path|
        c = Spree::CategoryTaxon.find_by_full_path(cat_path)
        if c
          s << "%30s => %60s, d = %d, id = %d\n" % [ioffer_cat.name, c.breadcrumb, c.depth, c.id]
          ioffer_cat.category_to_taxons.find_or_create_by(taxon_id: c.id)
        end
      end
    end.size
    puts s
  end

  def down
    drop_table_if_exists :category_to_taxons
  end
end
