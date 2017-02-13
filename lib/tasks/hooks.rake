namespace :hooks do
  desc 'Print a list of object names that can be hooked'
  task :objects => :environment do
    Rails.application.config.eager_load_namespaces.each(&:eager_load!)
    puts ActiveRecord::Base.descendants.collect(&:name).collect(&:underscore).sort
  end

  desc 'Print a list of event names for a given object, e.g. hooks:events[host/managed]'
  task :events, [:object] => :environment do |t,args|
    model = begin
              args[:object].camelize.constantize
            rescue NameError => e
              fail("Unknown model #{args[:object]}, run hooks:objects to get a list (#{e.message})")
            end

    events = ActiveRecord::Callbacks::CALLBACKS.map(&:to_s).reject { |e| e.start_with?('around_') }
    events.concat(['create', 'destroy', 'update']) if model.included_modules.include?(Orchestration)
    puts events.sort
  end
end
