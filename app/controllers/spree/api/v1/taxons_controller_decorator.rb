module Spree::Api::V1::TaxonsControllerDecorator
  def self.prepended(base)
    
  end

  def index
    @taxons = if taxonomy
                taxonomy.root.children.where('depth != 2')
              elsif params[:ids]
                Spree::Taxon.includes(:children).accessible_by(current_ability).where(id: params[:ids].split(','))
              else
                params[:q] ||= {}
                params[:q][:depth_gt] = 1
                Spree::Taxon.includes(:children).where('depth != 2').accessible_by(current_ability).order(:taxonomy_id, :lft)
              end
    @taxons = @taxons.ransack(params[:q]).result
    @taxons = @taxons.page(params[:page]).per(params[:per_page])
    respond_with(@taxons)
  end

end

Spree::Api::V1::TaxonsController.prepend(Spree::Api::V1::TaxonsControllerDecorator) if Spree::Api::V1::TaxonsController.included_modules.exclude?(Spree::Api::V1::TaxonsControllerDecorator)