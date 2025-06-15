module Spree::PrototypeDecorator

  def self.prepended(base)
  end

  def generate_related_option_types!
    list = []
    taxons.each do|taxon|
      option_types.each do|ot|
        list << Spree::RelatedOptionType.find_or_create_by(record_type:'Taxon', record_id: taxon.id, option_type_id: ot.id)
      end
    end
    list
  end

  ##
  # @option_type_name_match [Regexp] to limit option types w/ certain rule for name
  def generate_option_type_values_based_on_taxons!(option_type_name_match = nil)
    taxons.each do|taxon|
      applying_option_types = option_types.includes(:option_values).all.find_all{|ot| option_type_name_match.nil? || option_type_name_match.match(ot.presentation) }
      taxon_ids = taxon.categories_in_path.collect(&:id)
      taxon_ids.each do|taxon_id|
        puts "Taxon #{taxon_id} ----------------------------------"
        Spree::Classification.joins(:product).where(taxon_id: taxon_id).each do|c|
          puts "Product (#{c.product_id}): #{c.product.name}"
          applying_option_types.each do|option_type|
            product_ot = Spree::ProductOptionType.find_or_create_by(product_id: c.product_id, option_type_id: option_type.id)
            puts "  * #{option_type.presentation}" if product_ot
            puts "    #{option_type.option_values.size} option_values"
            option_type.option_values.each do|ov|
              matching_v = product_ot.product.variants.joins(:option_value_variants).where(spree_option_value_variants:{ option_value_id: ov.id } ).first
              if matching_v.nil?
                matching_v = product_ot.product.variants.create(user_id: product_ot.product.user_id )
                matching_v.price ||= product_ot.product.price
                matching_v.save
                Spree::OptionValueVariant.create(variant_id: matching_v.id, option_value_id: ov.id)
              end
            end
          end
        end
      end
    end
  end
end

Spree::Prototype.prepend(Spree::PrototypeDecorator) if Spree::Prototype.included_modules.exclude?(Spree::PrototypeDecorator)