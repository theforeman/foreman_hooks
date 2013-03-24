require 'foreman_hooks'
require 'foreman_hooks/hooks_observer'
require 'foreman_hooks/orchestration_hook'

module ForemanHooks
  class Engine < ::Rails::Engine
    config.to_prepare do
      # Register an observer to all classes with hooks present
      ForemanHooks::HooksObserver.observed_classes.each do |klass|
        klass.observers << ForemanHooks::HooksObserver
        klass.instantiate_observers
      end

      # Find any orchestration related hooks and register in those classes
      ForemanHooks::HooksObserver.hooks.each do |klass,events|
        orchestrate = false
        events.keys.each do |event|
          orchestrate = true if ['create', 'update', 'destroy'].include? event
        end
        klass.send(:include, ForemanHooks::OrchestrationHook) if orchestrate
      end
    end
  end
end
