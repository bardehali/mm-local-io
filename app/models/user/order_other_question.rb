module User
  class OrderOtherQuestion < OrderMessage
    def show_only_to_recipient?
      true
    end
  end
end