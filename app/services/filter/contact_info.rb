module Filter
  class ContactInfo

    def self.regexp
      @@regexp ||= /\b(contact|email|[\w\-\._]{2,}@[\w]{2,}\.[a-z]{2,4}|@gmail|@aol|wechat|whatsapp|messenger|hotmail|@yahoo|@icloud|@outlook|@qq|@sina|@mail\.ru|docomo\.com?|docomopacific)\b/i
    end
  end
end