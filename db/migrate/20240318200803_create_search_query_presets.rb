class CreateSearchQueryPresets < ActiveRecord::Migration[6.0]
  def change
    create_table :search_query_presets do |t|
      t.json :es_json
      t.string :identifier

      t.timestamps
    end
    add_index :search_query_presets, :identifier
  end
end
