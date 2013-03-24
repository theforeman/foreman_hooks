# foreman_hooks

Allows you to trigger scripts and commands on the Foreman server at any point
in an object's lifecycle in Foreman.  This lets you run a script when a host
is created, or finishes provisioning etc.

It observes every object in Foreman and exposes the Rails callbacks by running
scripts within its hooks directory.

# Installation:

Include in your `~foreman/bundler.d/foreman_hooks.rb`

    gem 'foreman_hooks'

Or from git:

    gem 'foreman_hooks', :git => "https://github.com/domcleal/foreman_hooks.git"

Regenerate Gemfile.lock:

    cd ~foreman && sudo -u foreman bundle install

To upgrade to newest version of the plugin:

    cd ~foreman && sudo -u foreman bundle update foreman_hooks

# Usage

Hooks are stored in `/usr/share/foreman/config/hooks` (`~foreman/config/hooks`)
with a subdirectory for the object, then a subdirectory for the event name.
Each file within the directory is executed in alphabetical order.

Examples:

    ~foreman/config/hooks/smart_proxy/after_create/01_email_operations.sh
    ~foreman/config/hooks/host/before_provision/50_do_something.sh
    ~foreman/config/hooks/host/managed/after_destroy/15_cleanup_database.sh

Note that in Foreman 1.1, hosts are just named `Host` so hooks go in a `host/`
directory, while in Foreman 1.2 they're `Host::Base` and `Host::Managed`, so
the hook directory becomes `host/base/` and `host/managed/` respectively.

## Objects / Models

Every object (or model in Rails terms) in Foreman can have hooks.  Check
`~foreman/app/models` for the full list, but these are the interesting ones:

* `host` (Foreman 1.1), `host/managed` (Foreman 1.2)
* `host/discovered` (Foreman 1.2)
* `report`

## Events

These are the most interesting events that Rails provides and this plugin
exposes:

* `after_create`
* `after_destroy`

Every event has a "before" and "after" hook.  For the full list, see the
Constants section at the bottom of the
[ActiveRecord::Callbacks](http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html)
documentation.

The host object has two special callbacks in Foreman 1.1 that you can use:

* `host/after_build` triggers when a host is put into Build mode(??)
* `host/before_provision` triggers... (??)

## Execution of hooks

Hooks are executed in the context of the Foreman server, so usually under the
`foreman` user.  One argument is provided, which is the string representation
of the object that was hooked, e.g. the hostname for a host.  No other data
about the object is currently made available.

# Copyright

Copyright (c) 2012-2013 Red Hat Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
