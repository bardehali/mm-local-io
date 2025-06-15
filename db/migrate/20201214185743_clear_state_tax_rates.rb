class ClearStateTaxRates < ActiveRecord::Migration[6.0]
  def change
    no_tax = Spree::TaxRate.find_by(name:'No tax')
    no_tax.update(show_rate_in_label: false) if no_tax
    Spree::TaxRate.where("name != 'No tax'").all.each(&:delete)
  end
end
