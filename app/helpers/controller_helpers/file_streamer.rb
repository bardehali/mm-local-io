require 'csv'

module ControllerHelpers
  module FileStreamer
    extend ActiveSupport::Concern

    def stream_csv_file(query, csv_header = nil, filename = nil)
      filename ||= query.model.to_s.split('::').last.downcase.pluralize + "-#{Time.zone.now.to_date.to_s(:default)}.csv"
      # Tell Rack to stream the content
      headers.delete("Content-Length")
  
      # Don't cache anything from this generated endpoint
      headers["Cache-Control"] = "no-cache"
  
      # Tell the browser this is a CSV file
      headers["Content-Type"] = "text/csv"
  
      # Make the file download with a specific filename
      headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
  
      # Don't buffer when going through proxy servers
      headers["X-Accel-Buffering"] = "no"
  
      headers["Last-Modified"] = Time.zone.now.ctime.to_s
      
      # Set the status to success
      response.status = 200
  
      self.response_body = stream_body(query, csv_header)
    end

    ##
    #
    def stream_body(query, csv_header = nil)
      Enumerator.new do |y|
        begin
          y << CSV.generate_line(csv_header) if csv_header
          # ApplicationRecord.iterate_the_query(query.page(1).limit(nil) ) do |record|
          query.extend(ApplicationRecord::RelationActions)
          query.iterate_in_batches(20) do|record|
            row_values = make_row_of(record)
            if row_values.is_a?(Array) && row_values.first.is_a?(Array)
              row_values.each do|r|
                y << CSV.generate_line( r )
              end
            else
              y << CSV.generate_line( row_values )
            end
          end
        rescue Exception => e
          Spree::User.logger.warn "Problem w/ error: #{e}\n#{e.backtrace.join("\n . ")}"
        end
      end
    end

    # query.find_each # This occurs: "Scoped order is ignored, it's forced to be batch order."
    # which results in only sorting by 'id ASC' w/o control.
    def stream_body_using_find_each(query, csv_header = nil)
      Enumerator.new do |y|
        begin
          y << CSV.generate_line(csv_header) if csv_header
          query.page(1).limit(nil).find_in_batches(batch_size: 100) do |group|
            group.each do|record|
              y << CSV.generate_line( make_row_of(record)  )
            end
          end
        rescue Exception => e
          Spree::User.logger.warn "Problem w/ error: #{e}"
        end
      end
    end

    private

    def make_row_of(record)
      record.respond_to?(:to_row) ? record.to_row : general_to_row(record)
    end

    def general_to_row(record)
      h = record.attributes
      h.keys.collect{|k| h[key] }
    end
  end
end