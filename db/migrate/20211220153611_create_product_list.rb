class CreateProductList < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :product_lists do |t|
      t.string  :name, limit: 400, nil: false
      t.timestamps
    end
    add_index_unless_exists :product_lists, :name

    create_table_unless_exists :product_list_products do|t|
      t.integer :product_list_id
      t.integer :product_id
      t.datetime :created_at
    end

    add_index_unless_exists :product_list_products, :product_list_id
    add_index_unless_exists :product_list_products, [:product_list_id, :product_id]
  end

  def down
    drop_table_if_exists :product_lists
    drop_table_if_exists :product_list_products
  end
end
