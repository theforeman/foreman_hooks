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
              logger.info "Finished registering #{hooks.size} hooks for #{Host::Base.to_s}##{event}"
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
                Bundler.with_clean_env { system(*args) }
              else
                system(*args)
              end

    unless success
      logger.warn "Hook failure running `#{args.join(' ')}`: #{$?}"
    end
    success
  end
end
