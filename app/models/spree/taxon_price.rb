module Spree
  class TaxonPrice < Spree::Base
    self.table_name = 'spree_taxon_prices'

    belongs_to :taxon

    def self.import_from_csv(file_path = nil)
      file_path = File.join(Rails.root, 'data/Phantom Item Category Prices.csv')
      non_live = (Rails.env.test? || Rails.env.development?)
      CSV.parse( File.open(file_path), headers: true ).each do|csv_row|

        cat = (non_live) ? nil : ::Spree::Taxon.find_by_id( csv_row[0].to_i )
        cat ||= ::Spree::Taxon.parse_breadcrumb( csv_row[1] )
        puts "| #{csv_row[1] } => #{cat.id}, actual #{cat.breadcrumb}"
        
        cat.taxon_prices.delete_all

        2.upto(csv_row.size - 1) do|col_i|
          next if csv_row[col_i].nil? || csv_row[col_i].to_f == 0.0
          cat.taxon_prices.create(price: csv_row[col_i].to_f)
          puts "  $#{csv_row[col_i] }"
        end
      end
    end # def
  end
end