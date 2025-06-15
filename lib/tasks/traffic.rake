namespace :traffic do
  task :request_info => :environment do
    LOG_REQUEST_LINE = 'Started GET '
    LOG_REQUEST_LINE_REGEXP = /\A\s*Started\s+GET\s+"(.+)"\s+for\s+([\d\.]+)\s+at\s(.+)\Z/i
    URL_PREFIX_REGEXP = /(.+)\/[^\/]+/
    IOFFER_LEGECY_URL_REGEXP = /\/(search\/items|si|i|items|c|w|want_?ads|img\d*|buy|buy_nows|ratings|offers\/new|questions\/\w+|shopping_carts|selling)[\?\/]/
    IOFFER_URL_TO_COLLECT_REGEXP = /\A\/(c|img|img2|img3|items)/
    
    ARGV.shift # script name
    files = []
    while (f = ARGV.shift).present?
      files << f
    end
    puts "Files to analyze: #{files}"

    time_start = nil
    time_end = nil
    total_requests_count = 0
    ip_to_request_counts = {}
    ip_to_request_patterns = {} # ip => { pattern => count }
    request_pattern_to_counts = {}
    urls_to_collect = {} # url_action => Array of URLs

    files.each do|file_path|
      puts "#{file_path} ---------------------------------"
      File.open(file_path, 'r') do|f|
        f.readlines.each do|line|
          begin
            m = line.match(LOG_REQUEST_LINE_REGEXP)
            next if m.nil?
            ip = m[2]
            url = m[1]
            url_prefix = url.match(URL_PREFIX_REGEXP).try(:[], 1)
            next if url_prefix.nil? # 1st level only

            t = Time.parse(m[3])
            # puts '%20s | %25s | %s' % [m[2], m[3], m[1] ]
            time_start = t if time_start.nil? || t < time_start
            time_end = t if time_end.nil? || t > time_end

            ip_to_request_count = ip_to_request_counts[ip] || 0
            ip_to_request_counts[ip] = ip_to_request_count + 1
            if (ioffer_m = url_prefix.match(IOFFER_LEGECY_URL_REGEXP) )
              url_action = ioffer_m[1]
              if url_prefix =~ IOFFER_URL_TO_COLLECT_REGEXP
                urls_to_collect[url_action] ||= []
                urls_to_collect[url_action] << url
              end
              ip_to_request_patterns[ip] ||= {}
              ip_to_request_patterns_h = ip_to_request_patterns[ip]
              ip_to_request_pattern_count = ip_to_request_patterns_h[ url_action] || 0
              ip_to_request_patterns[ip].merge!( url_action => ip_to_request_pattern_count + 1 )

              request_pattern_to_count = request_pattern_to_counts[ url_action ] || 0
              request_pattern_to_counts[ url_action ] = request_pattern_to_count + 1
            end
            total_requests_count += 1
          rescue Exception => request_e
            puts "Problem #{request_e} w/\n  #{line}"
          end
        end
      end
    end # files.each

    puts "Total #{total_requests_count}, logs within #{(time_end - time_start) / 3600} hours, starting #{time_start}"
    request_count_to_ips = {}
    ip_to_request_counts.each_pair do|ip, cnt|
      request_count_to_ips[cnt] ||= ip
    end
    top_ip_request_counts = request_count_to_ips.keys.sort.reverse[0,10]
    # top_ip_with_requests = ActiveSupport::HashWithIndifferentAccess.new
    time_length = time_end.to_i - time_start.to_i
    puts "IPs with most requests:"
    top_ip_request_counts.each do|cnt|
      puts '%16s | %5d | %.2f per minute' % [ request_count_to_ips[cnt], cnt, cnt.to_f / time_length * 60 ]
    end
    puts "\nTop ioffer legacy pages:"
    request_pattern_to_counts.each_pair{|k,v| puts '%20s: %d' % [k, v] }
    
    urls_to_collect.each_pair do|url_action, urls|
      count_to_urls = {}
      url_to_counts = {}
      urls.each do|u|
        url_to_counts[u] ||= 0
        url_to_counts[u] += 1
      end
      url_to_counts.each_pair{|u, count| count_to_urls[count] ||= []; count_to_urls[count] << u }
      File.open( File.join(Rails.root, "shared/data/ioffer_pages_bots_visit_#{url_action}.#{Time.now.to_s(:db)}.csv"), 'w') do|f| 
        count_to_urls.keys.sort.reverse.each do|count|
          count_to_urls[count].each {|u| f.write("#{u},#{count}\n"); }
        end
      end
    end
  end
end