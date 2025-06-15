class CreateSpreeItemReviews < ActiveRecord::Migration[6.0]
  def change
    create_table :spree_item_reviews do |t|
      t.references :variant_adoption, null: false, foreign_key: { to_table: :spree_variant_adoptions }, index: false
      t.string :name, null: false
      t.datetime :reviewed_at, null: false
      t.string :avatar
      t.string :city
      t.string :state
      t.string :country_code, limit: 2
      t.string :size
      t.integer :rating, null: false
      t.integer :number, default: 0, null: false
      t.integer :rank, default: 0, null: false
      t.string :reason
      t.text :body, null: false
      t.integer :purchase_count, default: 0, null: false
      t.json :similar_item_ids  # Stores related item IDs

      t.timestamps
    end

    add_index :spree_item_reviews, :reviewed_at
    add_index :spree_item_reviews, :rating  # Index for sorting/filtering by rating
    add_index :spree_item_reviews, :variant_adoption_id, unique: false, name: 'idx_spree_item_reviews_variant_adoption'

  end
end
