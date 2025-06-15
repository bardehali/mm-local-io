##
# The non-retail or not-implemented payment methods that use of 
# external processor to transfer payment from buyer to seller. 
# Instead, this would leave seller to explain to or instruct 
# buyer how to pay.
module Spree
  class PaymentMethod::General < PaymentMethod

    def source_required?
      false
    end
  end
end