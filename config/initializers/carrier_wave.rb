CarrierWave.configure do|config|
  config.fog_provider = 'fog/aws'
  config.fog_credentials = {
    provider: 'AWS',
    aws_access_key_id: ENV['AMAZON_S3_ACCESS_KEY'] || 'AKIAXN3DCMLA5PEC72H5',
    aws_secret_access_key: ENV['AMAZON_S3_SECRET_ACCESS_KEY'] || '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',
    region: ENV['AMAZON_S3_REGION'] || 'us-east-1',
    #path_style: true
  }
  config.storage = :fog
  config.fog_directory = ENV['AMAZON_S3_BUCKET'] || "ioffer-#{Rails.env}"
  config.fog_public    = false
  # config.ignore_processing_errors = true
  # config.fog_attributes = { cache_control: "public, max-age=#{1.hour.to_i}" }
  # config.cache_dir     = "#{Rails.root}/tmp/uploads"
end

# Old MinIO alternative
# aws_access_key_id: ENV['MINIO_ACCESS_KEY'] || 'laMRJ2Wo8SpfDUjQ',
# aws_secret_access_key: ENV['MINIO_SECRET_KEY'] || 'x99UADYKK9lW0NgHR8XptKKxkGsIoHRg',
# region: 'us-east-1',
# host: ENV['MINIO_HOST'] || 'cdn-io.com',
# endpoint: ENV['MINIO_ENDPOINT'] || 'http://cdn-io.com:9000',
# config.fog_directory = ((Rails.env.staging? || Rails.env.production?) ? 'ioffer-assets' : "ioffer-assets-#{Rails.env}" )
