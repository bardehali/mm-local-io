class SearchLog < ApplicationRecord
  include CommonLog

  before_save :normalize_attributes

  KeywordsCount = Struct.new(:keywords, :count)

  ##
  # @return [Array of KeywordsCount/ Struct(keywords, count)]
  def self.cached_top_search_logs(count = 30)
    Rails.cache.fetch "search_log.top#{count}", expires_in: 6.hours do
      list = []
      self.group(:keywords).count.each_pair do|kw, c|
        list << KeywordsCount.new(kw, c)
      end
      list.sort!{|x,y| y.count <=> x.count }
      list[0, count]
    end
  end
  
  protected

  def normalize_attributes
    self.keywords = keywords.strip_naked[0,200] if keywords
  end
end