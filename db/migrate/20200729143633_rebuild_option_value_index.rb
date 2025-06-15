class RebuildOptionValueIndex < ActiveRecord::Migration[6.0]
  def change
    ::Spree::OptionValue.rebuild_index!
  end
end
