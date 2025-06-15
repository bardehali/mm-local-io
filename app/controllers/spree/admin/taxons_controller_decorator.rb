module Spree::Admin::TaxonsControllerDecorator

  def self.prepended(base)
    base.helper Spree::Admin::BaseHelper
    
    base.before_action :load_resource, only: [:related_option_types]
    base.before_action :set_option_types, only: [:update]
  end

  # Same except staying on edit form.
  def update
    logger.info "-------------- which rendering? "

    successful = @taxon.transaction do
      parent_id = params[:taxon][:parent_id]
      set_position
      set_parent(parent_id)

      @taxon.save!

      # regenerate permalink
      regenerate_permalink if parent_id

      set_permalink_params

      # check if we need to rename child taxons if parent name or permalink changes
      @update_children = true if params[:taxon][:name] != @taxon.name || params[:taxon][:permalink] != @taxon.permalink

      @taxon.create_icon(attachment: taxon_params[:icon]) if taxon_params[:icon]
      @taxon.update(taxon_params.except(:icon))
    end
    if successful
      flash[:success] = flash_message_for(@taxon, :successfully_updated)

      # rename child taxons
      rename_child_taxons if @update_children
      Rails.cache.delete(Spree::CategoryTaxon::TOP_LEVEL_CATEGORIES_CACHE_KEY) if @taxon.depth <= 1

      respond_with(@taxon) do |format|
        format.html { render :edit }
        format.json { render json: @taxon.to_json }
      end
    else
      respond_with(@taxon) do |format|
        format.html { render :edit }
        format.json { render json: @taxon.errors.full_messages.to_sentence, status: 422 }
      end
    end
  end

  def related_option_types
    respond_to do|format|
      format.js
    end
  end

  private

  def load_resource
    @taxon = Spree::Taxon.find(params[:id])
  end

  def set_option_types
    params.permit(:taxon, :id, :taxonomy_id, :taxon_id, :option_type_id)
    @taxonomy ||= Spree::Taxonomy.find(params[:taxonomy_id]) if params[:taxonomy_id]
    @taxon ||= @taxonomy ? @taxonomy.taxons.find(params[:id]) : Spree::Taxon.find(params[:id])

    if (option_type_ids = params[:taxon].try(:delete, :related_option_type_ids) )
      Spree::RelatedOptionType.where(record_type: @taxon.class.to_s, record_id: @taxon.id).delete_all
      position = 0
      option_type_ids.split(',').uniq.each_with_index do|ot_id, idx|
        @taxon.related_option_types.create(option_type_id: ot_id, position: idx + 1)
      end
    end
    if (searchable_option_type_ids = params[:taxon].try(:delete, :searchable_option_type_ids) )
      Spree::SearchableRecordOptionType.where(record_type: @taxon.class.to_s, record_id: @taxon.id).delete_all
      searchable_option_type_ids.split(',').uniq.each_with_index do|ot_id, idx|
        @taxon.searchable_record_option_types.create(option_type_id: ot_id, position: idx + 1)
      end
    end
  end
end

::Spree::Admin::TaxonsController.prepend Spree::Admin::TaxonsControllerDecorator if ::Spree::Admin::TaxonsController.included_modules.exclude?(Spree::Admin::TaxonsControllerDecorator)