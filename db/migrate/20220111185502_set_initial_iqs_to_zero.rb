class SetInitialIqsToZero < ActiveRecord::Migration[6.0]
  def change
    query = Spree::Product.not_reviewed.where("iqs > 0")
    puts "Total of #{query.count} not reviewed"
    query.update_all(iqs: 0)
  end
end
