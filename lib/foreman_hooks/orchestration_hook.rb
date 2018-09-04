require 'foreman_hooks/util'

module ForemanHooks::OrchestrationHook
  extend ActiveSupport::Concern
  include ForemanHooks::Util

  included do
    after_validation :queue_hooks_validate
    before_destroy :queue_hooks_destroy
  end

  def queue_hooks_validate
    return unless errors.empty?
    queue_hooks(new_record? ? 'create' : 'update')
    queue_hooks(new_record? ? 'postcreate' : 'postupdate')
  end

  def queue_hooks_destroy
    return unless errors.empty?
    queue_hooks('destroy')
    queue_hooks('postdestroy')
  end

  def queue_hooks(event)
    logger.debug "Observed #{event} hook on #{self}"
    unless is_a? Orchestration
      logger.error "#{self.class.to_s} doesn't support orchestration, can't run orchestration hooks: use Rails events instead"
      return
    end

    return unless hooks = ForemanHooks.find_hooks(self.class, event)
    logger.debug "Queuing #{hooks.size} hooks for #{self.class.to_s}##{event}"

    counter = 0
    hooks.each do |filename|
      basename = File.basename(filename)
      priority = basename =~ /^(\d+)/ ? $1 : 10000 + (counter += 1)
      logger.debug "Queuing hook #{filename} for #{self.class.to_s}##{event} at priority #{priority}"
      queue_to_use = (event =~ /^post/) ? post_queue : queue
      queue_to_use.create(:name => "Hook: #{filename}", :priority => priority.to_i,
        :action => [HookRunner.new(filename, self, event.to_s), event.to_s == 'destroy' ? :hook_execute_del : :hook_execute_set])
    end
  end

  # Orchestration runs methods against an object, so generate a runner for each
  # hook that will need executing
  class HookRunner
    def initialize(filename, obj, event)
      @filename = filename
      @obj = obj
      @event = event
    end

    def args
      [@obj.to_s]
    end

    def hook_execute_set
      @obj.exec_hook(@filename, @event, *args)
    end

    def hook_execute_del
      @obj.exec_hook(@filename, 'destroy', *args)
    end
  end
end
