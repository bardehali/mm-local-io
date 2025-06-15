class CreateSearchKeywords < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :search_keywords do |t|
      t.string :keywords, length: 255
      t.integer :search_count, default: 1
    end
    SearchKeyword.populate_from_search_logs!
  end

  def down
    drop_table_if_exists :search_keywords
  end
end
