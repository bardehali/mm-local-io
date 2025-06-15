require 'admin/server'
require 'admin/servers/manager'

module Admin
  class ServersController < Spree::Admin::BaseController
    layout 'spree/layouts/only_main_content'

    before_action :authorize_real_admin

    def index
      @title = 'Servers'
      @manager = Admin::Servers::Manager.new
      @servers = @manager.servers
      # test 
      # @servers = [ Admin::Server.new('running' => ['nginx', 'puma', 'elasticsearch', 'delayed_job']) ]
    end

    def restart_process
      @manager = Admin::Servers::Manager.new
      @servers = @manager.servers
      @server = @servers.find{|server| server.hostname == params[:server_hostname] }
      if @server
        klass = Admin::Servers::Process.find_class_of_process( params[:process_name] )
        if klass
          found_process = @server.find_all_processes(nil, true).find{|p| p.is_a?(klass) }

          @process = found_process || @server.running_proccesses.find{|p| p.is_a?(klass) }
          if @process && @process.can_be_restarted?
            logger.debug " -> #{@process.class} kill_process_command: #{@process.kill_process_command}"
            kill_output = @server.run_command(@process.kill_process_command)
            logger.debug "  output: -------------------------\n#{kill_output}"

            logger.debug " -> #{@process.class} start_process_command: #{@process.start_process_command}"
            start_output = @server.run_command(@process.start_process_command)
            logger.debug "  output: -------------------------\n#{start_output}"
          else
            logger.debug " ** No process of #{klass}"
          end
        else
          flash[:error] = "Server #{@server.hostname} does not recognize process #{params[:process_name] }"
        end
      else
        flash[:error] = "Server #{params[:server_hostname] } cannot be found"
      end

      if @process
        respond_to do|format|
          format.js
        end
      else
        respond_to do|format|
          format.js { render js:'' }
        end
      end
    end
  end
end