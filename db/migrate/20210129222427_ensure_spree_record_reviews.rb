class EnsureSpreeRecordReviews < ActiveRecord::Migration[6.0]
  def change
    create_table_unless_exists Spree::RecordReview.table_name do|t|
      t.string  :record_type, limit: 80, null: false
      t.integer :record_id, null: false
      t.string  :status_code, default: 20
      t.integer :previous_curation_score
      t.integer :new_curation_score
      t.integer :iqs
      t.timestamps
      
      t.index [:record_type, :record_id]
      t.index :status_code
    end
  end
end
