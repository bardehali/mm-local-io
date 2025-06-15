module User
  class OrderBrokenTrackingNumber < OrderNeedTrackingNumber
    def self.level
      1300
    end

    def recipient_must_respond?
      true
    end
  end
end