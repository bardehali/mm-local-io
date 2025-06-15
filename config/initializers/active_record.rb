module ActiveRecord
  class Migration

    def add_column_unless_exists(table_name, column_name, type, options = {})
      add_column(table_name, column_name, type, options) if not columns(table_name).collect(&:name).include?(column_name.to_s)
    end

    def remove_column_if_exists(table_name, *column_names)
      columns = columns(table_name).collect(&:name)
      remove_column(table_name, *column_names) if column_names.all? { |col| columns.include?(col.to_s) }
    end
    alias_method :remove_columns_if_exists, :remove_column_if_exists

    def create_table_unless_exists(table_name, options = {}, &block)
      create_table(table_name, options, &block) if not table_exists?(table_name)
    end

    def drop_table_if_exists(table_name)
      drop_table table_name if table_exists?(table_name)
    end

    def remove_index_if_exists(table_name, columns)
      remove_index table_name, columns if index_exists?(table_name, columns)
    end

    def add_index_unless_exists(table_name, columns, options = {})
      add_index table_name, columns, options if not index_exists?(table_name, columns)
    end

    def column_exists?(table_name, column_name, column_type = nil)
      columns(table_name).collect(&:name).include?(column_name.to_s)
    end

  end
end