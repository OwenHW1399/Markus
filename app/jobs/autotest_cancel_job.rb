class AutotestCancelJob < ApplicationJob
  queue_as MarkusConfigurator.autotest_cancel_queue

  def perform(host_with_port, test_run_ids)
    if Rails.application.config.action_controller.relative_url_root.nil?
      markus_address = host_with_port
    else
      markus_address = host_with_port + Rails.application.config.action_controller.relative_url_root
    end
    server_username = MarkusConfigurator.autotest_server_username
    server_command = MarkusConfigurator.autotest_server_command
    server_params = { markus_address: markus_address, run_ids: test_run_ids }

    begin
      if server_username.nil?
        # local cancellation with no authentication
        cancel_command = [server_command, 'cancel', '-j' , JSON.generate(server_params)]
        output, status = Open3.capture2e(cancel_command)
        if status.exitstatus != 0
          raise output
        end
      else
        # local or remote cancellation with authentication
        server_host = MarkusConfigurator.autotest_server_host
        Net::SSH.start(server_host, server_username, auth_methods: ['publickey']) do |ssh|
          cancel_command = "#{server_command} cancel -j '#{JSON.generate(server_params)}'"
          output = ssh.exec!(cancel_command)
          if output.exitstatus != 0
            raise output
          end
        end
      end
      # TODO: Use output for something?
    rescue StandardError => e
      # TODO: Where to show failure? (when there is a way to show failure, the following code should not be ensured)
    ensure
      TestRun.find(test_run_ids).each { |test_run| test_run.update(time_to_service: -1) }
    end
  end
end
