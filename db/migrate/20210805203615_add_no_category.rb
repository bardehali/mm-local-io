class AddNoCategory < ActiveRecord::Migration[6.0]
  def change
    no_cat = Spree::Taxonomy.categories_taxonomy.taxons.where(name: 'No Category')
    unless no_cat
      no_cat = Spree::Taxon.create(name: 'No Category', taxonomy_id: Spree::Taxonomy.categories_taxonomy.id, parent_id: Spree::CategoryTaxon.root.id, hide_from_nav: true)
      no_cat.move_to_child_of(Spree::CategoryTaxon.root)
    end
  end
end
