#!/usr/bin/env python
#######
# To allow this module to be imported by other triggers
# execute the commands below:
# $ mkdir -p /usr/share/foreman-community/hooks
# $ touch /usr/share/foreman-community/hooks/__init__.py
# $ cp functions.py /usr/share/foreman-community/hooks/
########
import json
import sys
import tempfile

HOOK_TEMP_DIR = "/usr/share/foreman/tmp"

# HOOK_EVENT = update, create, before_destroy etc.
# HOOK_OBJECT = to_s representation of the object, e.g. host's fqdn
HOOK_EVENT, HOOK_OBJECT = (sys.argv[1], sys.argv[2])


def get_json_hook():
    '''
        Create JSON object to be imported by hook/trigger
        Saves the data received via stdin to file.
        It does not require to save to a file, but it may be useful
        to troubleshooting.
    '''

    with tempfile.NamedTemporaryFile(
            dir=HOOK_TEMP_DIR,
            # set to False for troubleshooting
            delete=True,
            prefix="foreman_hooks.") as hook:

        json_hook = sys.stdin.read()
        hook.file.write(json_hook)
        hook.file.flush()
    return json.loads(json_hook)
