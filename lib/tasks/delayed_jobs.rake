require File.join(Rails.root, 'lib/tasks/task_helper')
require File.join(Rails.root, 'lib/tasks/server_helper')
include ::TaskHelper
include ::ServerHelper

####################################
# Tasks

namespace :jobs do
  ##
  # There can be cases when Delayed::Job of same record_class + record_id gets 
  # duplicate entries scheduled.  This would minimize each to one.
  task :clean => [:environment] do
    puts "#################################\nTime: #{Time.now.to_s(:db)}"
    puts "Total delayed_jobs: #{Delayed::Job.count}"
    q = Delayed::Job.where('record_class is not null')
    records_count = q.all.collect{|j| [j.record_class, j.record_id] }.uniq.size
    puts "#{records_count} unique"
    q.all.group_by{|j| [j.record_class, j.record_id, j.performable_method_name] }.each_pair do|k, list|
      next if k[0].nil? || list.size < 2
      puts "#{k} has #{list.size}"
      Delayed::Job.where(id: list[1, list.size - 1] ).delete_all
    end
  end
end