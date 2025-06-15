class Spree::UserSellingTaxon < ApplicationRecord
  self.table_name = 'spree_user_selling_taxons'

  belongs_to :user
  belongs_to :taxon

  validates_presence_of :user_id, :taxon_id

  def self.populate_for(user_id)
    list = []
    transaction do
      where(user_id: user_id).delete_all

      current_values = Set.new
      ::Spree::Product.where("user_id=?", user_id).includes(:classifications).each do|p|
        p.classifications.each do|cls|
          unless current_values.include?(cls.taxon_id)
            current_values << cls.taxon_id
            list << find_or_create_by(user_id: user_id, taxon_id: cls.taxon_id)
          end
        end
      end
    end
    list
  end
end