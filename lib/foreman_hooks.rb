module ForemanHooks
  require 'foreman_hooks/engine' if defined?(Rails) && Rails::VERSION::MAJOR == 3
end
