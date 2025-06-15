module StrftimeOrdinal
  def self.included( base )
    base.class_eval do
      alias_method :old_strftime, :strftime
      def strftime( format )
        old_strftime format.gsub( "%o", day.ordinalize )
      end

      ##
      # Result like "Jan 9, 2023 4:44 PM"
      def to_mid_s(arg = nil)
        strftime('%b %-d, %Y %-l:%M %p')
      end

      ##
      # @return [Integer]
      def distance_of_time_ago(compared_to_time = nil, time_unit = 1.day)
        compared_to_time ||= Time.now
        ((compared_to_time - self) / time_unit).to_i
      end

      def relatively_days_ago(compared_to_time = nil)
        distance_of_time_ago(compared_to_time, 1.day)
      end

      def relatively_hours_ago(compared_to_time = nil)
        distance_of_time_ago(compared_to_time, 1.hour)
      end

    end
  end
end

[ Time, Date, DateTime ].each{ |c| c.send :include, StrftimeOrdinal }
