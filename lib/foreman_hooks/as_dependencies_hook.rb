module ForemanHooks
  module ASDependenciesHook
    def load_missing_constant(from_mod, constant_name)
      super(from_mod, constant_name).tap do |ret|
        return ret unless ret.try(:name)
        ForemanHooks.hooks.each do |klass,events|
          ForemanHooks.attach_hook(ret, events) if ret.name == klass
        end
      end
    end
  end

  ActiveSupport::Dependencies.singleton_class.send(:prepend, ASDependenciesHook)
end
