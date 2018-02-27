require 'open3'

module ForemanHooks::Util
  extend ActiveSupport::Concern

  def render_hook_type
    case self.class.name
      when "Host::Managed"
        'host'
      when "Host::Discovered"
        'discovered_host'
      when "Audited::Adapters::ActiveRecord::Audit", "Audited::Audit"
        'audit'
      else
        self.class.name.downcase
    end
  end

  def rabl_path
    "api/v2/#{render_hook_type.tableize}/show"
  end

  def render_hook_json
    # APIv2 has some pretty good templates.  We could extend them later in special cases.
    # Wrap them in a root node for pre-1.4 compatibility
    view_path = ActionController::Base.view_paths.collect(&:to_path)
    json = Rabl.render(self, rabl_path,
                       view_path: view_path, format: :json, scope: RablScope.new)
    %Q|{"#{render_hook_type}":#{json}}|
  rescue => e
    logger.warn "Unable to render #{self} (#{self.class}) using RABL: #{e.message}"
    logger.debug e.backtrace.join("\n")
    self.to_json
  end

  def exec_hook(*args)
    unless File.executable?(args.first)
      logger.warn("Hook #{args.first} no longer exists or isn't executable, so skipping execution of the hook. The server should be restarted after adding or removing hooks.")
      return true
    end

    logger.debug "Running hook: #{args.join(' ')}"
    success, output = if defined? Bundler && Bundler.responds_to(:with_clean_env)
                        Bundler.with_clean_env { exec_hook_int(render_hook_json, *args) }
                      else
                        exec_hook_int(render_hook_json, *args)
                      end
    # Raising here causes Foreman Orchestration to correctly show error bubble in GUI
    raise ForemanHooks::Error.new "Hook failure running `#{args.join(' ')}`: #{$?} #{output}" unless success
    success
  end

  def exec_hook_int(stdin_data, *args)
    args.map!(&:to_s)
    output, status = if Open3.respond_to? :capture2e
      Open3.capture2e(*args.push(:stdin_data => stdin_data))
    else  # 1.8
      Open3.popen3(*args) do |stdin,stdout,stderr|
        begin
          stdin.write(stdin_data)
          stdin.close
        rescue Errno::EPIPE
          logger.debug "Foreman hook input data skipped, closed pipe"
        end
        # we could still deadlock here, it'd ideally select() on stdout+err
        output = stderr.read
      end
      [output, $?]
    end
    logger.debug "Hook output: #{output}" if output && !output.empty?
    [status.success?, output]
  end

  class RablScope
    def initialize
      # Used by api/v2/hosts/main.json.yaml to include parameter lists
      @all_parameters = true
      @parameters = true
    end

    def params
      # Used by app/views/api/v2/common/show_hidden.json.rabl to show hidden parameter values (#17653)
      { 'show_hidden' => true, 'show_hidden_parameters' => true }
    end
  end
end
