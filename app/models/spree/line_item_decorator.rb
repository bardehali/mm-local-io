module Spree::LineItemDecorator

  def self.prepended(base)
    base.before_create :set_product_attributes
    base.extend ClassMethods

    base.include ::Spree::UserRelatedScopes

    # Need to refer to even deleted variant
    with_options inverse_of: :line_items do
      base.belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'
    end

    base.has_one :product, through: :variant

    base.belongs_to :variant_adoption, -> { with_deleted }, class_name:'Spree::VariantAdoption'

    ::Spree::PermittedAttributes.class_variable_set :@@line_item_attributes,
      ::Spree::PermittedAttributes.line_item_attributes + [:variant_adoption_id]

    base.whitelisted_ransackable_associations += %w[order]
  end

  module ClassMethods
    def default_per_page
      20
    end

    def row_header
      ['Item ID', 'Title', 'Category', 'Price']
    end
  end

  def to_s
    { variant_id: variant_id, product_id: product_id, quantity: quantity }
  end

  ##
  # Some fake transaction or bad transaction might have nil quantity
  def total_corrected
    [quantity.to_i, 1].max * (price || order.price)
  end

  def display_total
    Spree::Money.new(total_corrected, currency: order.currency)
  end

  def to_row
    # Based on ['Item ID', 'Title', 'Category', 'Price']
    [product_id, product&.name, product&.taxons&.first&.breadcrumb, total_corrected.to_f]
  end

  def set_user_ip(current_ip_address)
    self.request_ip = current_ip_address
  end

  def set_display_prices(browse_display_price, detail_price)
    self.browse_display_price = browse_display_price
    self.detail_display_price = detail_price
  end

  protected

  def set_product_attributes
    self.quantity = 1 if quantity.to_i < 1
    self.product_id = variant.product_id unless self.product_id
    self.current_view_count = variant.product&.view_count
  end

  def update_price_from_modifier(currency, opts)
    self.variant_adoption = Spree::VariantAdoption.find_by(id: opts[:variant_adoption_id]) if self.id.nil? && opts[:variant_adoption_id]
    return super(currency, opts) if variant_adoption.nil?

    # same as super except using pricing in variant_adoption
    if currency
      self.currency = currency
      # variant.price_in(currency).amount can be nil if
      # there's no price for this currency
      self.price = (variant_adoption.price_in(currency).amount || 0) +
        variant.price_modifier_amount_in(currency, opts)
    else
      self.price = variant_adoption.price +
        variant.price_modifier_amount(opts)
    end
  end
end

Spree::LineItem.prepend(Spree::LineItemDecorator) if Spree::LineItem.included_modules.exclude?(Spree::LineItemDecorator)
