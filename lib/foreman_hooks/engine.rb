require 'foreman_hooks'

module ForemanHooks
  class Engine < ::Rails::Engine
    config.to_prepare do
      ForemanHooks.hooks.each { |klass,events| ForemanHooks.attach_hook(klass.constantize, events) }
    end
  end
end
