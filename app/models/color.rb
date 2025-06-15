class Color
  attr_accessor :rgb_values

  def initialize(*args)
    @rgb_values = []
    if args.size == 1 && args.first.is_a?(String)
      @rgb_values = convert_to_rgb_array(args.first.gsub(/\A(#)/i,'' ) )
    else
      @rgb_values = convert_rgb_array(args)
    end
  end

  def hex_value
    @rgb_values.collect{|v| to_hex(v) }.join('')
  end

  ##
  # Compared to @opposite_hex_value, this sums up RGB values 
  # and provides a distinct color.
  # @return [String] joined hex values
  def opposite_text_value
    avg = @rgb_values.sum / 3
    c = if avg > 152 
      to_hex(0)
    elsif @rgb_values.find{|v| v > 203 }
      to_hex(51)
    else
      to_hex(204)
    end
    "#{c}#{c}#{c}"
  end

  ##
  # Compared to @opposite_hex_value, this sums up RGB values 
  # and provides a blended background color.
  # @return [String] joined hex values
  def opposite_bg_hex_value
    c = to_hex( @rgb_values.sum / 3 )
    "#{c}#{c}#{c}"
  end

  ##
  # Use of @opposite_rgb_values.
  def opposite_hex_value
    s = ''
    opposite_rgb_values do|v|
      s << to_hex(v)
    end
    s
  end

  # @return [Array of Integer]
  def opposite_rgb_values(&block)
    @rgb_values.collect do|v|
      s = (v + 153) % 255
      yield s if block_given?
      s
    end
  end

  protected

  def to_hex(i)
    i < 16 ? '%02d' % [i] : i.to_s(16)
  end

  ##
  # Separate @joined value into separate RGB values.
  def convert_to_rgb_array(joined_value)
    copy = joined_value.clone
    if copy.size == 3
      copy.collect{|v| v.to_i(16) }
    else
      char_per_color = copy.size / 3
      values = []
      0.upto(2) do|i|
        values << copy[i * char_per_color, char_per_color].to_i(16)
      end
      values
    end
  end

  ##
  # From an array of RGB values, whether each integer or string value
  def convert_rgb_array(array)
    array.collect do|v|
      v.is_a?(Integer) ? (v % 256) : v.to_i(16)
    end
  end
end