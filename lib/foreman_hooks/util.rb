require 'open3'

module ForemanHooks::Util
  extend ActiveSupport::Concern

  def exec_hook(*args)
    logger.debug "Running hook: #{args.join(' ')}"
    success = if defined? Bundler && Bundler.responds_to(:with_clean_env)
                Bundler.with_clean_env { exec_hook_int(self.to_json, *args) }
              else
                exec_hook_int(self.to_json, *args)
              end.success?

    # Raising here causes Foreman Orchestration to correctly show error bubble in GUI
    raise ForemanHooks::Error.new "Hook failure running `#{args.join(' ')}`: #{$?}" unless success
    success
  end

  def exec_hook_int(stdin_data, *args)
    output, status = if Open3.respond_to? :capture2e
      Open3.capture2e(*args.push(:stdin_data => stdin_data))
    else  # 1.8
      Open3.popen3(*args) do |stdin,stdout,stderr|
        stdin.write(stdin_data)
        stdin.close
        # we could still deadlock here, it'd ideally select() on stdout+err
        output = stderr.read
      end
      [output, $?]
    end
    logger.debug "Hook output: #{output}" if output && !output.empty?
    status
  end
end
