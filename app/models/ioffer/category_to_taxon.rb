class Ioffer::CategoryToTaxon < ApplicationRecord
  self.table_name = 'category_to_taxons'

  belongs_to :category, class_name:'Ioffer::Category'
  belongs_to :taxon, class_name:'Spree::Taxon'
end