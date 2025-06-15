class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ##
  # More actions to manage ActiveRecord::Relation
  module RelationActions

    ##
    # Keeps the order while in_batches/find_in_batch resets order to id ASC.
    # This does duplicate and reset already set page & per (offset & limit) to start fresh.
    def iterate_in_batches(batch_size = 100, &block)
      q2 = self.dup.limit(batch_size)
      0.upto( (count.to_f / batch_size).to_i ) do|batch_index| # not rounded
        q2.offset(batch_index * batch_size).each do|record|
          yield record
        end
      end
    end

    def reset_includes_values
      self.includes_values = []
    end

    def record_class
      @record_class ||= self.name.constantize
    end

    ##
    # Only @base_columns (default only id) plus order method
    def select_minimal_columns(base_columns = nil)
      select_cols = base_columns || ["#{record_class.table_name}.id"]
      self.order_values.each{|o| select_cols << ( o.is_a?(Arel::Nodes::Ordering) ? o.expr.name : o.split(/\s+/).first ) }
      logger.debug "| SQL: #{self.to_sql}"
      logger.debug "| while selecting #{select_cols}"
      self.select( select_cols.join(', ') )
    end
  end

  ##
  # Explictly list of all the columns in SQL's select clause.
  # Using along w/ @overriding_column_names could modify results such 
  # as 'id' => 'distinct(id) as id'
  def self.select_explictly(columns_to_exclude = [], overriding_column_names = {})
    col_names = []
    self.columns.each do|col|
      next if columns_to_exclude.include?(col.name)
      if (override = overriding_column_names[col.name] )
        col_names << override
      else
        col_names << "`#{table_name}`.`#{col.name}`"
      end
    end
    select(col_names.join(', ') )
  end

  # @attribute_name_or_time [Time or Symbol]
  def timestamp_with_slashes(attribute_name_or_time)
    return '' if attribute_name_or_time.nil?
    time = attribute_name_or_time.is_a?(Time) ? attribute_name_or_time : self.send(attribute_name_or_time)
    return '' if time.nil?
    time.strftime('%m/%d/%Y %k:%M')
  end
end
