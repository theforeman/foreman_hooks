require 'foreman_hooks'
require 'foreman_hooks/hooks_observer'

module ForemanHooks
  class Engine < ::Rails::Engine
    config.to_prepare do
      ForemanHooks::HooksObserver.observed_classes.each do |klass|
        klass.observers << ForemanHooks::HooksObserver
        klass.instantiate_observers
      end
    end
  end
end
