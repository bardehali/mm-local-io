class Spree::UserSellingOptionValue < ApplicationRecord
  self.table_name = 'spree_user_selling_option_values'

  belongs_to :user
  belongs_to :option_value

  validates_presence_of :user_id, :option_value_id

  def self.populate_for(user_id)
    list = []
    transaction do
      where(user_id: user_id).delete_all

      brand = ::Spree::OptionType.brand
      current_values = Set.new
      ::Spree::Variant.joins(:option_values).
        where("#{Spree::Variant.table_name}.user_id=? and option_type_id=?", user_id, brand.id).
        includes(:option_values).each do|v|
          v.option_values.each do|ov|
            next if ov.option_type_id != brand.id
            unless current_values.include?(  ov.id )
              current_values << ov.id
              list << find_or_create_by(user_id: user_id, option_value_id: ov.id)
            end
          end
        end
    end
    list
  end
end