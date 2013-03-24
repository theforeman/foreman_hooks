module ForemanHooks
  class HooksObserver < ActiveRecord::Observer
    def self.logger
      Rails.logger
    end

    def self.hooks_root
      File.join(Rails.application.root, 'config', 'hooks')
    end

    # Find all executable hook files under $hook_root/model_name/event_name/
    def self.search_hooks
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
        @hooks = search_hooks
        @hooks.each do |klass,events|
          events.each do |event,hooks|
            logger.info "Finished adding #{hooks.size} hooks to #{Host::Base.to_s}##{event}"
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

    # Override ActiveRecord::Observer
    def self.observed_classes
      hooks.keys
    end

    def respond_to?(method)
      return true if super
      self.class.events.include? method
    end

    def method_missing(event, *args)
      obj = args.first
      logger.debug "Observed #{event} hook on #{obj}"

      return unless hooks = self.class.hooks[obj.class]
      return unless hooks = hooks[event.to_s]
      return if hooks.empty?

      logger.debug "Running #{hooks.size} hooks for #{obj.class.to_s}##{event}"
      hooks.each { |filename| exec_hook(filename, obj.to_s) }
    end

    def exec_hook(*args)
      logger.debug "Running hook: #{args.join(' ')}"
      success = if defined? Bundler && Bundler.responds_to(:with_clean_env)
                  Bundler.with_clean_env { system(*args) }
                else
                  system(*args)
                end

      unless success
        logger.warn "Hook failure running `#{args.join(' ')}`: #{$?}"
      end
    end

    def logger
      Rails.logger
    end
  end
end
