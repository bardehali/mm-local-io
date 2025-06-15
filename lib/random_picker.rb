class RandomPicker
  ##
  # More than just numbers[0, wanted_count].  This would determine 
  # the range/boundaries of the values if @range_or_total_count is not
  # a range, within 10% to 90%.
  def self.pick_indices(wanted_count, range_or_total_count)
    range = if range_or_total_count.is_a?(Range)
        range_or_total_count
      else
        if range_or_total_count < wanted_count
          0..(range_or_total_count - 1)
        else
          first_index = [0, (range_or_total_count * rand(1..3) / 10.0 ).round - 1 ].max
          last_index = [range_or_total_count - 1, (range_or_total_count * rand(7..9) / 10.0).round - 1 ].min
          first_index..last_index
        end
      end
      range.to_a.shuffle[0, wanted_count].compact
  end
end