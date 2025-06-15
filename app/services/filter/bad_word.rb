module Filter
  class BadWord

    def self.cache
      Rails.cache.fetch 'data.bad_words' do
        reload_from_data_file
      end
    end

    def self.regexp
      @@regexp ||= Regexp.new('\b(' + cache.join('|') + ')\b', Regexp::IGNORECASE)
    end

    def self.reload_from_data_file
      bad_words = []
      file_path = Rails.root.join('data', 'bad_words.txt')
      f = File.new(file_path)
      f.each {|line| next if line.blank?; bad_words << line.strip.downcase }
      bad_words
    end
  end
end