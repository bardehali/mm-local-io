Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_jobs.log'), 10, 102400)
Delayed::Worker.max_attempts = 10