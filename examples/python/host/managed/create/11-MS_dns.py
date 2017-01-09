#!/usr/bin/env python
import sys
import tempfile
import subprocess

sys.path.append('/usr/share/foreman/config')
from hook_functions import \
    (HOOK_EVENT, HOOK_OBJECT, HOOK_TEMP_DIR, get_json_hook)

PREFIX = "created_by_hook-{}".format(sys.argv[0].split('/')[-1])

HOOK_JSON = get_json_hook()

# read the information received
domain = ".{0}".format(HOOK_JSON.get('host').get('domain'))
hostname = HOOK_JSON.get('host').get('name').replace(domain, '')
ip_addr = HOOK_JSON.get('host').get('ip')

DNSCMD = "Add-DnsServerResourceRecordA -Name {0}" \
         " -ZoneName example.com -AllowUpdateAny -IPv4Address {1}" \
         " -CreatePtr".format(hostname, ip_addr)

# execute logger command
subprocess.call(['logger', 'Running', 'ssh user@example.com', DNSCMD])

# run remote command
subprocess.call(['ssh', 'user@example.com', DNSCMD])

# for troubleshooting purposes, you can save the received data to a file
# to parse the information to be used on the trigger.
# To accomplish it, set the variable dumpdata to True
dumpdata = False
if dumpdata:
    with tempfile.NamedTemporaryFile(dir=HOOK_TEMP_DIR,
                                     delete=False,
                                     prefix=PREFIX) as fd:
        fd.file.write("HOOK_OBJECT: %s\n" % HOOK_OBJECT)
        fd.file.write("HOOK_EVENT:  %s\n" % HOOK_EVENT)
        fd.file.write("HOOK_JSON:   %s\n" % HOOK_JSON)

        # local variables
        fd.file.write("hostname:    %s\n" % hostname)
        fd.file.flush()

sys.exit(0)
