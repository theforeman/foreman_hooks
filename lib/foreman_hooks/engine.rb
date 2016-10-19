require 'foreman_hooks'

module ForemanHooks
  class Engine < ::Rails::Engine
    config.to_prepare do
      ForemanHooks.hooks.each do |klass,events|
        begin
          klass_const = klass.constantize
        rescue NameError => e
          ForemanHooks.logger.error "foreman_hooks: unknown hook object #{klass}, check against `foreman-rake hooks:objects`"
          next
        end
        ForemanHooks.attach_hook(klass_const, events)
      end
    end

    initializer 'foreman_hooks.register_plugin', :before => :finisher_hook do |app|
      Foreman::Plugin.register :foreman_hooks do
      end
    end
  end
end
