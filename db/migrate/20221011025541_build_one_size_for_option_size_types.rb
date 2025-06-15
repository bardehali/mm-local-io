class BuildOneSizeForOptionSizeTypes < ActiveRecord::Migration[6.0]
  def change
    Spree::OptionType.where("name='size' OR name LIKE '%size' OR name LIKE '%sizes'").each do|ot|
      one_size = ot.option_values.where(presentation: 'one size').first
      puts "| #{ot.name} w/ one_size #{one_size}"
      unless one_size
        one_size = ot.option_values.create(name: "One #{ot.name}".titleize, presentation:'One Size')
      end
    end

    # some double size word may happen
    Spree::OptionValue.where("name LIKE '%size size' OR name LIKE '%sizes size'").each{|ov| ov.name.gsub!(/(sizes?\s+)size\Z/i, ''); puts "#{ov.name} save? #{ov.save}"; }.class
  end
end
