namespace :hooks do
  desc 'Print a list of object names that can be hooked'
  task :objects => :environment do
    Rails.application.config.eager_load_namespaces.each(&:eager_load!)

    # Gather the models
    models = ActiveRecord::Base.descendants.collect(&:name).collect(&:underscore)

    # filter out known models not hookable
    models.reject! {|e| e.start_with?('habtm')}

    puts models.sort
  end

  desc 'Print a list of event names for a given object, e.g. hooks:events[host/managed]'
  task :events, [:object] => :environment do |t,args|
    model = begin
              args[:object].camelize.constantize
            rescue NameError => e
              fail("Unknown model #{args[:object]}, run hooks:objects to get a list (#{e.message})")
            end

    # 1. List default ActiveRecord callbacks
    events = ActiveRecord::Callbacks::CALLBACKS.map(&:to_s).reject { |e| e.start_with?('around_') }

    # 2. List Foreman orchestration callbacks
    events.concat(['create', 'destroy', 'update', 'postcreate', 'postupdate', 'postdestroy']) if model.included_modules.include?(Orchestration)

    # 3. List custom define_callbacks/define_model_callbacks
    callbacks = model.methods.map { |m| $1 if m =~ /\A_([a-z]\w+)_callbacks\z/ }.compact
    # ignore callbacks that are in the AR default list
    callbacks.delete_if { |c| events.any? { |e| e.end_with?("_#{c}") } }
    callbacks.each { |c| events.push("before_#{c}", "after_#{c}") }

    puts events.sort
  end
end
