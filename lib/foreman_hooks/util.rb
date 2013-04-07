require 'open3'

module ForemanHooks::Util
  extend ActiveSupport::Concern

  included do
    class_eval do
      def self.hooks_root
        File.join(Rails.application.root, 'config', 'hooks')
      end

      # Find all executable hook files under $hook_root/model_name/event_name/
      def self.discover_hooks
        hooks = {}
        Dir.glob(File.join(hooks_root, '**', '*')) do |filename|
          next if filename.end_with? '~'
          next if filename.end_with? '.bak'
          next if File.directory? filename
          next unless File.executable? filename

          relative = filename[hooks_root.size..-1]
          next unless relative =~ %r{^/(.+)/([^/]+)/([^/]+)$}
          klass = $1.camelize.constantize
          event = $2
          script_name = $3
          hooks[klass] ||= {}
          hooks[klass][event] ||= []
          hooks[klass][event] << filename
          logger.debug "Found hook to #{klass.to_s}##{event}, filename #{script_name}"
        end
        hooks
      end

      # {ModelClass => {'event_name' => ['/path/to/01.sh', '/path/to/02.sh']}}
      def self.hooks
        unless @hooks
          @hooks = discover_hooks
          @hooks.each do |klass,events|
            events.each do |event,hooks|
              logger.info "Finished registering #{hooks.size} hooks for #{klass.to_s}##{event}"
              hooks.sort!
            end
          end
        end
        @hooks
      end

      # ['event1', 'event2']
      def self.events
        @events = hooks.values.map(&:keys).flatten.uniq.map(&:to_sym) unless @events
        @events
      end

      def self.logger; Rails.logger; end
    end
  end

  def find_hooks(klass, event)
    return unless filtered = self.class.hooks[klass]
    return unless filtered = filtered[event.to_s]
    return if filtered.empty?
    filtered
  end

  def exec_hook(*args)
    logger.debug "Running hook: #{args.join(' ')}"
    success = if defined? Bundler && Bundler.responds_to(:with_clean_env)
                Bundler.with_clean_env { exec_hook_int(self.to_json, *args) }
              else
                exec_hook_int(self.to_json, *args)
              end.success?

    unless success
      logger.warn "Hook failure running `#{args.join(' ')}`: #{$?}"
    end
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
