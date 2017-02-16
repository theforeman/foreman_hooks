#!/bin/bash

# This file provides additional debug information for foreman-debug tool and is
# symlinked as /usr/share/foreman/script/foreman-debug.d/50-foreman_hooks

add_cmd "find /usr/share/foreman/config/hooks/ -type f -executable" "foreman_hooks_list"
