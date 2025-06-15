class Hash < Object
  ##
  # In the structure of [key => Array of values],
  # join the values of the other hash for each values if already exists
  # in this hash keyed values; otherwise, would create new entry of pair.
  def merge_values!(other_hash, unique_values = true, &block)
    other_hash.each_pair do|other_key, other_values|
      current_values = self[other_key].to_a
      yield other_key, current_values, other_values if block_given?
      values = (current_values + other_values)
      values.uniq! if unique_values
      self[other_key] = values
    end
  end

  ##
  # For Hash that has structure of key => Array of values,
  # this would add @v to existing list or make a new list w/ the @v
  # @return [Array] resulting list of values
  def add_into_list_of_values(k, v)
    list = self[k]
    if list
      list << v # since pointer, no need to set again like self[k] = list
    else
      list = [v]
      self[k] = list
    end
    list
  end

  def increment_count(k, more_count = 1)
    self[k] = self[k].to_i + more_count
  end

  ##
  # Recursive search inside the hash for value of the given @field.
  def self.find_value_in(key, obj)
    v = nil
    if obj.is_a?(Hash)
      v = obj[key]
      if v.nil?
        v = find_value_in(key, obj.values)
      end
    elsif obj.is_a?(Array)
      obj.each{|ae| v = find_value_in(key, ae) if v.nil? }
    end
    v
  end
end