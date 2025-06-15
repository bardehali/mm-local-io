class CreateHpSellerRole < ActiveRecord::Migration[6.0]
  def change
    role = Spree::Role.find_or_create_by(name: 'hp_seller') do|r|
      r.level = 250
    end
  end
end
