class ProductKeyword < ApplicationRecord

  PRODUCT_ATTRIBUTES_TO_COLLECT = [:name]
  ##
  # Those that should be replaced w/ spaces
  REPLACEABLE_PUNCTUATIONS = /([\|"';:,\(\)\[\]\{\}\<\>\?]+)/
  ##
  # Iterates through attributes, breaks up into words,
  # and calls @log_keyword
  def self.log_product(product)
    PRODUCT_ATTRIBUTES_TO_COLLECT.each do|a|
      if (s = product.send(a)&.strip_naked).present?
        s.gsub!(REPLACEABLE_PUNCTUATIONS, ' ')
        s.split(/[\s]+/).each do|kw|
          log_keyword(kw)
        end
      end
    end
  end

  def self.log_keyword(keyword)
    kw = self.find_by(keyword: keyword.strip)
    if kw
      kw.occurence = kw.occurence.to_i + 1
      kw.save
    end
    kw
  end
end