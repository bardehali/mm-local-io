class CreateSpreeSellingOptionValues < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :spree_user_selling_option_values do |t|
      t.integer :user_id, null: false
      t.integer :option_value_id, null: false
      t.index :user_id
    end

    brand_ot = Spree::OptionType.find_or_create_by(name:'brand') do|r|
        r.presentation = 'Brand'
      end
    brand_name_to_option_value_map = brand_ot.option_values.where(
      presentation: Ioffer::Brand.all.collect(&:presentation) ).all.
      group_by{|b| b.presentation.downcase }

    Ioffer::User.joins(:brands).all.each do|ioffer_user|
      spree_user = Spree::User.where(username: ioffer_user.username).first
      next if spree_user.nil?
      ioffer_user.brands.each do|b|
        brand_option_value = brand_name_to_option_value_map[b.presentation.downcase].try(:first)
        if brand_option_value
          spree_user.user_selling_option_values.find_or_create_by(option_value_id: brand_option_value.id)
        end
      end
    end
  end

  def down
    drop_table_if_exists :spree_user_selling_option_values 
  end
end
