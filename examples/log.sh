#!/bin/bash

. $(dirname $0)/hook_functions.sh

# event name (create, before_destroy etc.)
# orchestration hooks must obey this to support rollbacks (create/update/destroy)
event=${HOOK_EVENT}

# to_s representation of the object, e.g. host's fqdn
object=${HOOK_OBJECT}

# Example of using hook_data to query the JSON representation of the object
# passed by foreman_hooks.  `cat $HOOK_OBJECT_FILE` to see the contents.
hostname=$(hook_data host.name)

echo "$(date): received ${event} on ${object}" >> /tmp/hook.log

# exit code is important on orchestration tasks
exit 0
