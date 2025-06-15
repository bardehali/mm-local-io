class AddRecordClassAndIdToDelayedJobs < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :delayed_jobs, :record_class, :string, limit: 128
    add_column_unless_exists :delayed_jobs, :record_id, :integer
    add_index_unless_exists :delayed_jobs, [:record_class, :record_id], name: 'idx_delayed_jobs_record_class_id'
  end

  def down
    remove_index_if_exists :delayed_jobs, [:record_class, :record_id]
    remove_column_if_exists :delayed_jobs, :record_class
    remove_column_if_exists :delayed_jobs, :record_id
  end
end
