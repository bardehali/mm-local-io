class RecalculateLegacySellerRank < ActiveRecord::Migration[6.0]
  def change
    q = Spree::User.where('seller_rank >= 2000000')
    puts "Total of #{q.count} legacy sellers"
    q.each do|u|
      u.calculate_stats!
    end
  end
end
