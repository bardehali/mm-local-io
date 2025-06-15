$redis = Redis.new(url:  ENV['REDIS_URL'], password: ENV['REDIS_PASSWORD'],
  port: ENV['REDIS_PORT'],
  db:   ENV['REDIS_DB'] || '0')