module ForemanHooks
  require 'foreman_hooks/engine'
  require 'foreman_hooks/util'
  require 'foreman_hooks/as_dependencies_hook'
  require 'foreman_hooks/callback_hooks'
  require 'foreman_hooks/orchestration_hook'

  class Error < RuntimeError; end

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
            logger.info "Finished discovering #{hooks.size} hooks for #{klass}##{event}"
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
                   Hash[hooks.select { |k,e| k == klass }]
                 else
                   hooks
                 end
      filtered.values.map(&:keys).flatten.uniq.map(&:to_sym)
    end

    def find_hooks(klass, event)
      klass = klass.name if klass.kind_of? Class
      return unless filtered = hooks[klass]
      return unless filtered = filtered[event.to_s]
      return if filtered.empty?
      filtered
    end

    def attach_hook(klass, events)
      if events.keys.detect { |event| ['create', 'update', 'destroy', 'postcreate', 'postupdate', 'postdestroy'].include? event }
        unless klass.ancestors.include?(ForemanHooks::OrchestrationHook)
          logger.debug "Extending #{klass} with foreman_hooks orchestration hooking support"
          klass.send(:include, ForemanHooks::OrchestrationHook)
        end
      end

      unless klass.ancestors.include?(ForemanHooks::CallbackHooks)
        logger.debug "Extending #{klass} with foreman_hooks Rails hooking support"
        klass.send(:include, ForemanHooks::CallbackHooks)
      end
    end

    def logger; Rails.logger; end
  end
end
