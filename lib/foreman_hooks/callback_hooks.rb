require 'foreman_hooks/util'

module ForemanHooks::CallbackHooks
  extend ActiveSupport::Concern
  include ForemanHooks::Util

  included do
    ForemanHooks.events(self).each do |event|
      filter, name = event.to_s.split('_', 2)
      next unless name

      Rails.logger.debug("Created hook method #{event} on #{self}")
      if "#{event}" == "before_destroy"
        set_callback name.to_sym, filter.to_sym, "#{event}_hooks".to_sym, prepend: true
      else
        set_callback name.to_sym, filter.to_sym, "#{event}_hooks".to_sym
      end
      define_method("#{event}_hooks") do
        Rails.logger.debug "Observed #{event} hook on #{self}"
        return unless hooks = ForemanHooks.find_hooks(self.class, event)

        Rails.logger.debug "Running #{hooks.size} hooks for #{self.class.to_s}##{event}"
        hooks.each { |filename| exec_hook(filename, event.to_s, to_s) }
      end
    end
  end
end
