module Spree::Stock::CoordinatorDecorator

  def self.prepended(base)
    base.extend ClassMethods
  end

  module ClassMethods
    
  end

  ##
  # Since sellers are actuall 3rd-party ones, stock location means nothing.
  def build_packages(packages = [])
    Spree::StockLocation.all.each do |stock_location|
      packer = build_packer(stock_location, inventory_units)
      packages += packer.packages
    end

    packages
  end
end

Spree::Stock::Coordinator.prepend(Spree::Stock::CoordinatorDecorator) if Spree::Stock::Coordinator.included_modules.exclude?(Spree::Stock::CoordinatorDecorator)