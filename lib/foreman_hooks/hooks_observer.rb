require 'foreman_hooks/util'

module ForemanHooks
  class HooksObserver < ActiveRecord::Observer
    include ForemanHooks::Util

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
      return unless hooks = find_hooks(obj.class, event)

      logger.debug "Running #{hooks.size} hooks for #{obj.class.to_s}##{event}"
      hooks.each { |filename| exec_hook(filename, event.to_s, obj.to_s) }
    end

    def logger; Rails.logger; end
  end
end
