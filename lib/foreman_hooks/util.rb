require 'open3'

module ForemanHooks::Util
  extend ActiveSupport::Concern

  def render_hook_type
    case self
      when Host::Managed
        'host'
      else
        self.class.name.to_lower
    end
  end

  def render_hook_json
    # APIv2 has some pretty good templates.  We could extend them later in special cases.
    # Wrap them in a root node for pre-1.4 compatibility
    json = Rabl.render(self, "api/v2/#{render_hook_type.tableize}/show", :view_path => 'app/views', :format => :json)
    %Q|{"#{render_hook_type}":#{json}}|
  rescue => e
    logger.warn "Unable to render #{self} (#{self.class}) using RABL: #{e.message}"
    logger.debug e.backtrace.join("\n")
    self.to_json
  end

  def exec_hook(*args)
    logger.debug "Running hook: #{args.join(' ')}"
    success = if defined? Bundler && Bundler.responds_to(:with_clean_env)
                Bundler.with_clean_env { exec_hook_int(render_hook_json, *args) }
              else
                exec_hook_int(render_hook_json, *args)
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
