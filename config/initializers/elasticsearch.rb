Elasticsearch::Model::Response::Response.__send__ :include, Elasticsearch::Model::Response::Pagination::Kaminari

config = {
    host: 'http://elasticsearch:9200/',
    transport_options: {
        request: {timeout: 5}
    }
}

if File.exists?( Rails.root.join('config/elasticsearch.yml') )
  config.merge!(YAML.load_file( Rails.root.join('config/elasticsearch.yml') )[Rails.env].deep_symbolize_keys)
end

config['user'] = ENV['ELASTIC_SEARCH_USER'] if ENV['ELASTIC_SEARCH_USER'].present?
config['password'] = ENV['ELASTIC_SEARCH_PASSWORD'] if ENV['ELASTIC_SEARCH_PASSWORD'].present?

Elasticsearch::Model.client = Elasticsearch::Client.new(config)
