#!/usr/bin/env python
import json
import os
import sys
import tempfile

HOOK_TEMP_DIR="/usr/share/foreman/tmp"

# HOOK_EVENT = update, create, before_destroy etc.
# HOOK_OBJECT = to_s representation of the object, e.g. host's fqdn
HOOK_EVENT, HOOK_OBJECT = (sys.argv[1], sys.argv[2])

# saves the data received via stdin to file.
# it does not require to save to a file, but it may be useful
# to troubleshooting.
def get_json_hook():
    '''Create JSON object to be imported by hook/trigger'''
    with tempfile.NamedTemporaryFile(
            dir=HOOK_TEMP_DIR,
            #delete=False, #useful for troubleshooting
            prefix="foreman_hooks.") as hook:

        json_hook = sys.stdin.read()
        hook.file.write(json_hook)
        hook.file.flush()
    return json.loads(json_hook)

