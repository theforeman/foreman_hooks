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

RPM users can install the "tfm-rubygem-foreman_hooks" or
"rubygem-foreman_hooks" packages. Debian/Ubuntu users can install the
"ruby-foreman-hooks" package.

# Usage

Hooks are stored in `/usr/share/foreman/config/hooks` (`~foreman/config/hooks`)
with a subdirectory for the object, then a subdirectory for the event name.

    ~foreman/config/hooks/[OBJECT]/[EVENT]/[HOOK_SCRIPT]

Examples:

    ~foreman/config/hooks/host/managed/create/50_register_system.sh
    ~foreman/config/hooks/host/managed/destroy/15_cleanup_database.sh
    ~foreman/config/hooks/smart_proxy/after_create/01_email_operations.sh
    ~foreman/config/hooks/audited/audit/after_create/01_syslog.sh

After adding or removing hooks, restart the Foreman server to update the list
of known hooks (usually `apache2` or `httpd` when using Passenger, or
`touch ~foreman/tmp/restart.txt`).

## Objects / Models

Every object (or model in Rails terms) in Foreman can have hooks.  Check
`~foreman/app/models` for the full list, but these are the interesting ones:

* `host/managed`
* `config_report` (or `report` in Foreman 1.10 or older)
* `nic/managed`
* `hostgroup`
* `user`

To generate a list of *all* possible models, issue the following command:

    # foreman-rake hooks:objects

and to get events for a listed object (e.g. `host/managed`):

    # foreman-rake hooks:events[host/managed]

## Orchestration events

_Only supported on these objects:_

* _host/managed_
* _nic/\*_

Foreman supports orchestration tasks for hosts and NICs (each network
interface) which happen when the object is created, updated and destroyed.
These tasks are shown to the user in the UI and if they fail, will
automatically trigger a rollback of the action. A rollback is performed as
an opposite action (e.g. for DHCP record creation a rollback action is
destroy).

The following hooks are executed during `around_save` Rails callback:

* `create`
* `update`

The following hooks are executed during `on_destroy` Rails callback:

* `destroy`

The following hooks are executed during `after_commit` Rails callback:

* `postcreate`
* `postupdate`
* `postdestroy`

The major difference between `create` and `postcreate` (or update respectively) is how late the hook is called during save operation. In the former case when a hook fails it starts rollback and operation can be still cancelled. In the latter case object was already saved and there is no way of cancelling the operation, but all referenced data should be properly loaded. The advice is to use the latter hooks as they will likely contain all the required data (e.g. nested parameters).

Orchestration hooks can be given a priority by prefixing the filename with the
priority number, therefore it is possible to order them before or after
built-in orchestration steps (before DNS records are created for example).
Existing common priority levels are:

* _2_: Set up compute instance (create VM)
* _10_: Create DNS record
* _10_: Create DHCP reservation
* _20_: Deploy TFTP configs
* _50_: Create realm entry
* _1000_: Power up compute instance

## Rails events

_Supported on all object types._

For hooks on anything apart from hosts or NICs (which support orchestration,
as above) then the standard Rails events will be needed. These are the most
interesting events provided:

* `after_create`, `before_create`
* `after_destroy`, `before_destroy`

Every event has a "before" and "after" hook.  For the full list, see the
Constants section at the bottom of the
[ActiveRecord::Callbacks](http://api.rubyonrails.org/classes/ActiveRecord/Callbacks.html)
documentation.

The host object has two additional callbacks that you can use:

* `host/managed/after_build` triggers when a host is put into build mode (does
  not trigger upon new host creation, even when build flag is set)
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
may want to ensure stdin is closed to prevent pipe buffer from filling.

    echo '{"host":{"name":"foo.example.com"}}' \
      | ~foreman/config/hooks/host/managed/create/50_register_system.sh \
           create foo.example.com

Some arguments are available as environment variables:

Variable | Description
-------- | -----------
FOREMAN_HOOKS_USER | Username of Foreman user

Every hook within the event directory is executed in alphabetical order.  For
orchestration hooks, an integer prefix in the hook filename will be used as
the priority value, so influences where it's done in relation to DNS, DHCP, VM
creation and other tasks.

When testing hooks, don't rely on writing logs to /tmp or /var/tmp as you may
not be able to see the contents. On modern systemd-based OSes, Apache (and
Foreman) is run with a private temp directory to improve security - consider
using `~foreman/tmp/` instead, or read `/tmp/systemd-private-*` as root.

## Hook failures and rollback

If a hook fails (non-zero return code), the event is logged.  For Rails events,
execution of other hooks will continue.

For orchestration events, a failure will halt the action and rollback will
occur.  If another orchestration action fails, the hook might be called again
to rollback its action - in this case the first argument will change as
appropriate, so must be obeyed by the script (e.g. a "create" hook will be
called with "destroy" if it has to be rolled back later).

## Logging

Entries are logged at application startup and during execution of hooks, but
most will be at 'debug' level and may use the 'sql' logger. Enable this in
Foreman's `/etc/foreman/settings.yaml`:

```yaml
:logging:
  :level: debug
:loggers:
  :sql:
    :enabled: true
```

See [Foreman manual: Debugging](https://theforeman.org/manuals/latest/index.html#7.2Debugging)
for full details.

Enabling debugging and searching the Foreman log file (`/var/log/foreman/production.log`)
for the word "hook" will find all relevant log entries.

### Hook discovery and setup

Expect to see these entries when the server starts:

* `Found hook to Host::Managed#create, filename 01_example` - for each
  executable hook script in the correct location
* `Finished discovering 3 hooks for Host::Managed#create` - for each unique
  event with hook scripts
* `Extending Host::Managed with foreman_hooks orchestration hooking support` -
  if any orchestration (create/update/destroy) hooks exist for that object
* `Extending Host::Managed with foreman_hooks Rails hooking support` - if any
  Rails events hooks exist for that object
* `Created hook method after_create on Host::Managed` - for each type of Rails
  event that has hooks

### Running hooks

Expect to see these entries logged when a hooked action occurs:

* `Observed after_create hook on test.example.com` when a registered Rails
  event occurs, hook will then execute immediately
* `Queuing 3 hooks for Host::Managed#create` when an orchestration action is
  being set up (hook will be executed later during orchestration)
* `Queuing hook 01_example for Host::Managed#create at priority 01` for each
  hook registered when setting up an orchestration action
* `Running hook: /example/config/hooks/host/managed/create/01_example create test.example.com`
  as the hook (orchestration or Rails event) is executed

## Transactions

Most hooks are triggered during database transaction. This can cause
conflicting updates when hook scripts emits database updates via Foreman CLI
or API. It is recommended to avoid this behavior and write a Foreman plugin
instead.

## SELinux notes

When using official installation on Red Hat and Fedora system, note that
SELinux is turned on by default and Foreman is running in confined mode. Make
sure that hook scripts has the correct context (`foreman_hook_t` on
RHEL7+/Fedora 19+ or `bin_t` on RHEL6):

    restorecon -RvF /usr/share/foreman/config/hooks

Also keep in mind that the script is running confined, therefore some actions
might be denied by SELinux. Check audit.log and use audit2allow and other
tools when writing scripts.

# More resources

* [foreman\_hooks issue tracker](https://github.com/theforeman/foreman_hooks/issues)
* [Extending Foreman quickly with hook scripts](http://m0dlx.com/blog/Extending_Foreman_quickly_with_hook_scripts.html)
* [AWS VPC Buildout With Foreman Hooks for RDNS Creation](http://www.brian2.net/posts/foreman_hooks_aws_vpc/)
* [Foreman <-> FreeIPA Integration Guide](https://bitbin.de/blog/2013/11/foreman-freeipa-integration-guide/)
* [Autostart Libvirt/KVM VMs in Foreman](http://www.uberobert.com/autostart-libvirt-vms-in-foreman/)

# Copyright

Copyright (c) 2012-2017 Dominic Cleal

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
