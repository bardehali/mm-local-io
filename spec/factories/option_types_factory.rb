module Spree
  class OptionValue
    SAMPLE_VALUES = {
      color: %w|one_color white black grey red|,
      size: %w|xs s m l xl one_size|,
      shoe_size: %w|8 8.5 9 9.5 10 10.5 11 one_size|,
      brand: ['gucci', 'louis vuitton', 'nike', 'the north face', 'coach', 'adidas', 'off white', 'prada', 'yves saint laurent', 'tiffany', 'chanel', 'michael kors', 'burberry', 'jordan', 'cartier', 'hermes', 'bulgari', 'yeezy', 'bape', 'rayban', 'sony', 'apple', 'levis'],
      material: %w|cotton silk metal aluminum|,
    } unless defined?(SAMPLE_VALUES)
  end
end

FactoryBot.define do
  factory :option_type, class: Spree::OptionType do
    factory :option_type_color do
      name { 'color' }
      presentation { 'Color' }
      position { 1 }
      option_values { ::Spree::OptionValue::SAMPLE_VALUES[:color].collect{|v| build("option_value_#{v.downcase}".to_sym) } }
    end

    factory :option_type_size do
      name { 'size' }
      presentation { 'Size' }
      position { 2 }
      option_values { ::Spree::OptionValue::SAMPLE_VALUES[:size].collect{|v| build("option_value_#{v.downcase}".to_sym) } }
    end

    factory :option_type_shoe_size do
      name { 'shoe size' }
      presentation { 'Shoe Size' }
      position { 3 }
      option_values { ::Spree::OptionValue::SAMPLE_VALUES[:shoe_size].collect{|v| build("option_value_#{v.downcase}".to_sym) } }
    end

    factory :option_type_brand do
      name { 'brand' }
      presentation { 'Brand' }
      position { 4 }
      option_values { ::Spree::OptionValue::SAMPLE_VALUES[:brand].collect{|v| build("option_value_#{v.downcase}".to_sym) } }
    end

    factory :option_type_material do
      name { 'material' }
      presentation { 'Material' }
      position { 5 }
      option_values { ::Spree::OptionValue::SAMPLE_VALUES[:material].collect{|v| build("option_value_#{v.downcase}".to_sym) } }
    end

    factory :option_type_one_color do
      name { 'one color' }
      presentation { 'One Color' }
      position { 7 }
      option_values { [ build('option_value_one_color') ] }
    end

    factory :option_type_one_size do
      name { 'one size' }
      presentation { 'One Size' }
      position { 7 }
      option_values { [ build('option_value_one_size') ] }
    end
  end # option_types

  factory :option_value, class: Spree::OptionValue do
    ::Spree::OptionValue::SAMPLE_VALUES[:color].each.with_index do|_color, _index|
      factory "option_value_#{_color}".to_sym do
        position { _index }
        name { _color }
        presentation { _color.titleize }
        # option_type_id { find_or_create(:option_type_color, :name).id }
      end
    end

    ::Spree::OptionValue::SAMPLE_VALUES[:size].each.with_index do|_size, _index|
      factory "option_value_#{_size}".to_sym do
        position { _index }
        name { _size }
        presentation { _size.titleize }
        # option_type_id { find_or_create(:option_type_size, :name).id }
      end
    end

    ::Spree::OptionValue::SAMPLE_VALUES[:brand].each.with_index do|_brand, _index|
      factory "option_value_#{_brand.downcase}".to_sym do
        position { _index }
        name { _brand.downcase }
        presentation { _brand }
        # option_type_id { find_or_create(:option_type_brand, :name).id }
      end
    end

    ::Spree::OptionValue::SAMPLE_VALUES[:material].each.with_index do|_material, _index|
      factory "option_value_#{_material}".to_sym do
        position { _index }
        name { _material }
        presentation { _material.titleize }
        # option_type_id { find_or_create(:option_type_material, :name).id }
      end
    end
  end
end