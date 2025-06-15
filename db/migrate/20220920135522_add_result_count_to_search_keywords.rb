class AddResultCountToSearchKeywords < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :search_keywords, :result_count, :integer
    add_index_unless_exists :search_keywords, :keywords
    add_index_unless_exists :search_keywords, :search_count

    SearchKeyword.all.each do|kw|
      kw.set_result_count if kw.result_count.nil?
      kw.save
      kw.es.update_document
    end
  end

  def down
    remove_index_if_exists :search_keywords, :keywords
    remove_index_if_exists :search_keywords, :search_count
    remove_column_if_exists :search_keywords, :result_count
  end
end
