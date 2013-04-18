module ForemanHooks
  require 'foreman_hooks/engine' if defined?(Rails) && Rails::VERSION::MAJOR == 3
  require 'foreman_hooks/util'
  require 'foreman_hooks/callback_hooks'
  require 'foreman_hooks/orchestration_hook'

  class << self
    def hooks_root
      File.join(Rails.application.root, 'config', 'hooks')
    end

    # Find all executable hook files under $hook_root/model_name/event_name/
    def discover_hooks
      hooks = {}
      Dir.glob(File.join(hooks_root, '**', '*')) do |filename|
        next if filename.end_with? '~'
        next if filename.end_with? '.bak'
        next if File.directory? filename
        next unless File.executable? filename

        relative = filename[hooks_root.size..-1]
        next unless relative =~ %r{^/(.+)/([^/]+)/([^/]+)$}
        klass = $1.camelize
        event = $2
        script_name = $3
        hooks[klass] ||= {}
        hooks[klass][event] ||= []
        hooks[klass][event] << filename
        logger.debug "Found hook to #{klass.to_s}##{event}, filename #{script_name}"
      end
      hooks
    end

    # {'ModelClass' => {'event_name' => ['/path/to/01.sh', '/path/to/02.sh']}}
    def hooks
      unless @hooks
        @hooks = discover_hooks
        @hooks.each do |klass,events|
          events.each do |event,hooks|
            logger.info "Finished registering #{hooks.size} hooks for #{klass}##{event}"
            hooks.sort!
          end
        end
      end
      @hooks
    end

    # ['event1', 'event2']
    def events(klass = nil)
      filtered = if klass
                   klass = klass.name if klass.kind_of? Class
                   hooks.select { |k,e| k == klass }
                 else
                   hooks
                 end
      @events = filtered.values.map(&:keys).flatten.uniq.map(&:to_sym) unless @events
      @events
    end

    def find_hooks(klass, event)
      klass = klass.name if klass.kind_of? Class
      return unless filtered = hooks[klass]
      return unless filtered = filtered[event.to_s]
      return if filtered.empty?
      filtered
    end

    def logger; Rails.logger; end
  end
end

module ActiveSupport::Dependencies
  class << self
    def load_missing_constant_with_hooks(from_mod, constant_name)
      ret = load_missing_constant_without_hooks(from_mod, constant_name)
      ForemanHooks.hooks.each do |klass,events|
        next unless ret.name == klass
        if events.keys.detect { |event| ['create', 'update', 'destroy'].include? event }
          ret.send(:include, ForemanHooks::OrchestrationHook) unless ret.ancestors.include?(ForemanHooks::OrchestrationHook)
        end
        ret.send(:include, ForemanHooks::CallbackHooks) unless ret.ancestors.include?(ForemanHooks::CallbackHooks)
      end
      ret
    end

    alias_method_chain :load_missing_constant, :hooks
  end
end
