class CreateProductKeywordsTable < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :product_keywords do |t|
      t.string :keyword, null: false, length: 100
      t.integer :occurence, default: 1
    end
    add_index_unless_exists :product_keywords, :keyword
    add_index_unless_exists :product_keywords, :occurence
  end

  def down
    drop_table_if_exists :product_keywords
  end
end
