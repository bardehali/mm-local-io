module Spree::TaxonsControllerDecorator

  def self.prepended(base)
    base.include ControllerHelpers::ProductBrowser

    # base.before_action :authenticate_spree_user! unless Rails.env.development? || Rails.env.test?
    base.before_action :reset_params
  end

  def show
    @title = "#{@taxon.name} for Sale"
    load_products
  end

  private

  ##
  # Override database search.
  def load_products
    params[:taxon_ids] = [ @taxon.try(:id) ].compact
    load_products_with_searcher
  end


  def etag
    super + [spree_current_user.try(:admin?).to_s]
  end

end

Spree::TaxonsController.prepend(Spree::TaxonsControllerDecorator) if Spree::TaxonsController.included_modules.exclude?(Spree::TaxonsControllerDecorator)
