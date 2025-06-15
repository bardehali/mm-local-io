module Admin
  module ServersHelper
    extend ActiveSupport::Concern
    
    # @load_value [Float] up to 10.0
    # @return [String] either 'heavy', 'medium', 'light', 'minimal'
    def server_load_level(load_value)
      process_load_level(load_value.to_f * 10)
    end

    # @return [String] either 'heavy', 'medium', 'light', 'minimal'
    def process_load_level(cpu_usage)
      percent = cpu_usage.is_a?(Numeric) ? cpu_usage : cpu_usage.to_f
      if percent > 75
        'heavy'
      elsif percent >= 50
        'medium'
      elsif percent >= 25
        'light'
      else
        'minimal'
      end
    end
  end
end