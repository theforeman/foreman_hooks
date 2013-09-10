# foreman_hooks

Allows you to trigger scripts and commands on the Foreman server at any point
in an object's lifecycle in Foreman.  This lets you run scripts when a host
is created, or finishes provisioning etc.

It enables extension of Foreman's host orchestration so additional tasks can
be executed, and can register hooks into standard Rails callbacks for any
Foreman object, all with shell scripts.

# Installation:

Please see the Foreman wiki for appropriate instructions:

* [Foreman: How to Install a Plugin](http://projects.theforeman.org/projects/foreman/wiki/How_to_Install_a_Plugin)

The gem name is "foreman_hooks".

RPM users can install the "ruby193-rubygem-foreman_hooks" or
"rubygem-foreman_hooks" packages.

# Usage

Hooks are stored in `/usr/share/foreman/config/hooks` (`~foreman/config/hooks`)
with a subdirectory for the object, then a subdirectory for the event name.

    ~foreman/config/hooks/$OBJECT/$EVENT/$HOOK_SCRIPT

Examples:

    ~foreman/config/hooks/host/managed/create/50_register_system.sh
    ~foreman/config/hooks/host/managed/destroy/15_cleanup_database.sh
    ~foreman/config/hooks/smart_proxy/after_create/01_email_operations.sh

(`host/managed` is for Foreman 1.2+, change to just `host` for Foreman 1.1)

## Objects / Models

Every object (or model in Rails terms) in Foreman can have hooks.  Check
`~foreman/app/models` for the full list, but these are the interesting ones:

* `host/managed` (or `host` in Foreman 1.1)
* `report`

## Orchestration events

Foreman supports orchestration tasks for hosts and NICs (each network
interface) which happen when the object is created, updated and destroyed.
These tasks are shown to the user in the UI and if they fail, will
automatically trigger a rollback of the action.

To add hooks to these, use these event names:

* `create`
* `update`
* `destroy`

## Rails events

For hooks on anything apart from hosts (which support orchestration, as above)
then the standard Rails events will be needed.  These are the most interesting
events provided:

* `after_create`, `before_create`
* `after_destroy`, `before_destroy`

Every event has a "before" and "after" hook.  For the full list, see the
Constants section at the bottom of the
[ActiveRecord::Callbacks](http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html)
documentation.

The host object has two additional callbacks that you can use:

* `host/managed/after_build` triggers when a host is put into build mode
* `host/managed/before_provision` triggers when a host completes the OS install

## Execution of hooks

Hooks are executed in the context of the Foreman server, so usually under the
`foreman` user.

The first argument is always the event name, enabling scripts to be symlinked
into multiple event directories.  The second argument is the string
representation of the object that was hooked, e.g. the hostname for a host.

    ~foreman/config/hooks/host/managed/create/50_register_system.sh create foo.example.com

A JSON representation of the hook object will be passed in on stdin.  A utility
to read this with jgrep is provided in `examples/hook_functions.sh` and
sourcing this utility script will be enough for most users.  Otherwise, you
may want to ensure stdin is closed.

    echo '{"host":{"name":"foo.example.com"}}' \
      | ~foreman/config/hooks/host/managed/create/50_register_system.sh \
           create foo.example.com

Every hook within the event directory is executed in alphabetical order.  For
orchestration hooks, an integer prefix in the hook filename will be used as
the priority value, so influences where it's done in relation to DNS, DHCP, VM
creation and other tasks.

## Hook failures and rollback

If a hook fails (non-zero return code), the event is logged.  For Rails events,
execution of other hooks will continue.

For orchestration events, a failure will halt the action and rollback will
occur.  If another orchestration action fails, the hook might be called again
to rollback its action - in this case the first argument will change as
appropriate, so must be obeyed by the script (e.g. a "create" hook will be
called with "destroy" if it has to be rolled back later).

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
