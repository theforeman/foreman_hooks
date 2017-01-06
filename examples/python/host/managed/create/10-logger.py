#!/usr/bin/env python
import sys
import json
import tempfile
import subprocess

sys.path.append('/usr/share/foreman/config')
from hook_functions import HOOK_EVENT, HOOK_OBJECT, HOOK_TEMP_DIR, get_json_hook

PREFIX = "created_by_hook-{}".format(sys.argv[0].split('/')[-1])

HOOK_JSON = get_json_hook()

# read the information received
hostname = HOOK_JSON.get('host').get('name')
mac_address = HOOK_JSON.get('host').get('mac')
operating_system = HOOK_JSON.get('host').get('operatingsystem_name')

# execute logger command
subprocess.call(['logger',
                 'System', hostname,
                 'MAC', mac_address,
                 'OS:', operating_system,
                 'created successfully'])

# for troubleshooting purposes, you can save the received data to a file
# to parse the information to be used on the trigger.
# To accomplish it, set the variable dumpdata to True
dumpdata = False
if dumpdata:
    with tempfile.NamedTemporaryFile(dir=HOOK_TEMP_DIR, delete=False, prefix=PREFIX) as fd:
        fd.file.write("HOOK_OBJECT: %s\n" % HOOK_OBJECT)
        fd.file.write("HOOK_EVENT:  %s\n" % HOOK_EVENT)
        fd.file.write("HOOK_JSON:   %s\n" % HOOK_JSON)

        # local variables
        fd.file.write("hostname:    %s\n" % hostname)
        fd.file.write("mac_address: %s\n" % mac_address)
        fd.file.write("os:          %s\n" % operating_system)
        fd.file.flush()

sys.exit(0)
