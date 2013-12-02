require 'foreman_hooks'

module ForemanHooks
  class Engine < ::Rails::Engine
    config.to_prepare do
      ForemanHooks.hooks.each { |klass,events| ForemanHooks.attach_hook(klass.constantize, events) }
    end

    initializer 'foreman_hooks.register_plugin', :after=> :finisher_hook do |app|
      Foreman::Plugin.register :foreman_hooks do
      end if defined? Foreman::Plugin
    end
  end
end
