FactoryBot.define do
  factory :taxonomies, class: Spree::Taxonomy do
    factory :categories_taxonomy do
      name { 'Categories' }
      position { 1 }
    end

    factory :brand_taxonomy do
      name { 'Brand' }
      position { rand(10) + 1 }
    end
  end

  factory :taxons, class: Spree::Taxon do
    # position { 0 }
    # depth { 0 }
    taxonomy_id { ::Spree::CategoryTaxon.find_or_create_categories_taxonomy.id }
    before :create do|t|
      t.position = t.parent ? t.parent.children.select('max(position) as position').last.try(:position).to_i 
        : rand(50) + 1
    end

    trait :with_color_and_size_related_option_types do
      before :create do|t|
        t.option_types << find_or_create(:option_type_color)
        t.option_types << find_or_create(:option_type_size)
      end
    end

    trait :with_one_color_and_size_related_option_types do
      before :create do|t|
        t.option_types = [ find_or_create(:option_type_one_color), find_or_create(:option_type_one_size) ]
      end
    end

    trait :with_material_related_option_types do
      before :create do|t|
        t.option_types << find_or_create(:option_type_material)
      end
    end

    trait :with_categories_taxonomy do
      taxonomy_id { ::Spree::CategoryTaxon.find_or_create_categories_taxonomy.id }
    end

    trait :with_categories_root_parent do
      parent_id { ::Spree::CategoryTaxon.find_or_create_categories_taxonomy.root.id }
    end

    factory :level_one_category_taxon, aliases: [:clothing_category_taxon], 
      traits:[:with_color_and_size_related_option_types, :with_categories_taxonomy, :with_categories_root_parent] do
      name { 'Clothing' }
      permalink { 'categories/clothing' }
      position { 1 }
      taxon_prices { [15.25, 17.29, 19.35].collect{|price| Spree::TaxonPrice.new(price: price, currency:'USD') } }
    end

    factory :level_two_category_taxon, aliases: [:mens_clothing_category_taxon], traits:[:with_color_and_size_related_option_types, :with_categories_taxonomy] do
      name { "Men's Clothing" }
      permalink { 'categories/mens-clothing' }
      position { 2 }
      parent_id { find_or_create(:level_one_category_taxon, :name).id }
      taxon_prices { [23.23, 25.25, 26.26, 29.29, 30.30].collect{|price| Spree::TaxonPrice.new(price: price, currency:'USD') } }
    end

    factory :level_three_category_taxon, aliases: [:shirts_category_taxon], traits:[:with_color_and_size_related_option_types, :with_categories_taxonomy] do
      name { 'Shirts' }
      permalink { 'categories/mens-clothing-shirts' }
      position { rand(10) + 1 }
      parent_id { find_or_create(:level_two_category_taxon, :name).id }
      taxon_prices { [19.95, 21.35, 23.49, 25.15, 26.29].collect{|price| Spree::TaxonPrice.new(price: price, currency:'USD') } }
    end

    factory :bags_and_purses_taxon,
      traits:[:with_categories_taxonomy, :with_categories_root_parent] do
      name { 'Bags and Purses' }
      permalink { 'categories/bags-and-purses' }
      position { 3 }
      option_types { [ find_or_create(:option_type_color), find_or_create(:option_type_one_size) ] }
      taxon_prices { [39.95, 45.95, 55.49, 60.29].collect{|price| Spree::TaxonPrice.new(price: price, currency:'USD') } }
    end

    factory :home_taxon, traits:[:with_material_related_option_types, :with_categories_taxonomy] do
      name {'Home & Garden'}
      permalink {'categories/home-garden'}
      position { rand(10) + 1 }
    end

    factory :consumer_electronics_taxon, traits:[:with_one_color_and_size_related_option_types, :with_categories_taxonomy, :with_categories_root_parent] do
      name {'Consumer Electronics'}
      permalink {'categories/consumer-electronics'}
      position { rand(10) + 1 }
    end
  end
end