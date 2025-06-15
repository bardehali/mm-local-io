class PopulateTaxData < ActiveRecord::Migration[6.0]
  def change
    default_tax_calculator = Spree::Calculator::DefaultTax.last
    default_tax_calculator ||= Spree::Calculator::DefaultTax.create
    tax_category = Spree::TaxCategory.find_or_create_by(name:'Default') do|cat|
      cat.is_default = true
    end

    add_column_unless_exists :spree_tax_rates, :user_id, :string, limit: 64, default: nil
    add_index_unless_exists :spree_tax_rates, [:deleted_at, :user_id]

    no_tax = Spree::TaxRate.find_or_initialize_by(name: 'No tax') do|t|
      t.amount = 0.0
      t.tax_category_id ||= tax_category.id
      t.show_rate_in_label = false
    end
    no_tax.calculator ||= default_tax_calculator
    no_tax.save

    [
      ['North America', 'USA + Canada'],
      ['EU_VAT', 'Countries that make up the EU VAT zone'],
      ['South America', 'South America'],
      ['Middle East', 'Middle East'],
      ['Asia', 'Asia']
    ].each do|zone_ar|
      z = Spree::Zone.find_or_create_by(name: zone_ar.first) do|_z|
        _z.description = zone_ar[1]
        _z.kind = 'country'
      end
    end
    zone = Spree::Zone.where(name: ['North America', 'United States'] ).first

    [
      ['Alabama (AL) Sales Tax Rates', '4.000'],
      ['Alaska (AK) Sales Tax Rates', '0.000'],
      ['Arizona (AZ) Sales Tax Rates', '5.600'],
      ['Arkansas (AR) Sales Tax Rates', '6.500'],
      ['California (CA) Sales Tax Rates', '7.250'],
      ['Colorado (CO) Sales Tax Rates', '2.900'],
      ['Connecticut (CT) Sales Tax Rates', '6.350'],
      ['Delaware (DE) Sales Tax Rates', '0.000'],
      ['Florida (FL) Sales Tax Rates', '6.000'],
      ['Georgia (GA) Sales Tax Rates', '4.000'],
      ['Hawaii (HI) Sales Tax Rates', '4.000'],
      ['Idaho (ID) Sales Tax Rates', '6.000'],
      ['Illinois (IL) Sales Tax Rates', '6.250'],
      ['Indiana (IN) Sales Tax Rates', '7.000'],
      ['Iowa (IA) Sales Tax Rates', '6.000'],
      ['Kansas (KS) Sales Tax Rates', '6.500'],
      ['Kentucky (KY) Sales Tax Rates', '6.000'],
      ['Louisiana (LA) Sales Tax Rates', '4.450'],
      ['Maine (ME) Sales Tax Rates', '5.500'],
      ['Maryland (MD) Sales Tax Rates', '6.000'],
      ['Massachusetts (MA) Sales Tax Rates', '6.250'],
      ['Michigan (MI) Sales Tax Rates', '6.000'],
      ['Minnesota (MN) Sales Tax Rates', '6.875'],
      ['Mississippi (MS) Sales Tax Rates', '7.000'],
      ['Missouri (MO) Sales Tax Rates', '4.225'],
      ['Montana (MT) Sales Tax Rates', '0.000'],
      ['Nebraska (NE) Sales Tax Rates', '5.500'],
      ['Nevada (NV) Sales Tax Rates', '6.850'],
      ['New Hampshire (NH) Sales Tax Rates', '0.000'],
      ['New Jersey (NJ) Sales Tax Rates', '6.625'],
      ['New Mexico (NM) Sales Tax Rates', '5.125'],
      ['New York (NY) Sales Tax Rates', '4.000'],
      ['North Carolina (NC) Sales Tax Rates', '4.750'],
      ['North Dakota (ND) Sales Tax Rates', '5.000'],
      ['Ohio (OH) Sales Tax Rates', '5.750'],
      ['Oklahoma (OK) Sales Tax Rates', '4.500'],
      ['Oregon (OR) Sales Tax Rates', '0.000'],
      ['Pennsylvania (PA) Sales Tax Rates', '6.000'],
      ['Rhode Island (RI) Sales Tax Rates', '7.000'],
      ['South Carolina (SC) Sales Tax Rates', '6.000'],
      ['South Dakota (SD) Sales Tax Rates', '4.500'],
      ['Tennessee (TN) Sales Tax Rates', '7.000'],
      ['Texas (TX) Sales Tax Rates', '6.250'],
      ['Utah (UT) Sales Tax Rates', '4.850'],
      ['Vermont (VT) Sales Tax Rates', '6.000'],
      ['Virginia (VA) Sales Tax Rates', '4.300'],
      ['Washington (WA) Sales Tax Rates', '6.500'],
      ['West Virginia (WV) Sales Tax Rates', '6.000'],
      ['Wisconsin (WI) Sales Tax Rates', '5.000'],
      ['Wyoming (WY) Sales Tax Rates', '4.000']
    ].each do|state_ar|
      name = state_ar[0].gsub(/(\s*rates?)/i, '')
      state_tax = Spree::TaxRate.find_or_initialize_by(name: name, zone_id: zone.id)
      state_tax.amount = state_ar[1].to_f / 100.0
      state_tax.tax_category_id ||= tax_category.id
      state_tax.show_rate_in_label = true

      state_tax.calculator ||= Spree::Calculator.new(type: 'Spree::Calculator::DefaultTax',
        calculable_type: 'Spree::TaxRate')
      state_tax.save
      puts "#{name}, valid? #{state_tax.valid?}: #{state_tax.errors.messages}"
    end

  end
end
