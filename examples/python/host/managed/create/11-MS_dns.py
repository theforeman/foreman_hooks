#!/opt/rh/python27/root/usr/bin/python
#### make sure the repository rhel-server-rhscl-7-rpms is enabled
### yum install  libffi-devel python27-python-devel openssl-devel python27-python-pip gcc -y
### /opt/rh/python27/root/usr/bin/pip install paramiko

import sys
import tempfile
import paramiko

sys.path.append('/usr/share/foreman/config')
from hook_functions import \
    (HOOK_EVENT, HOOK_OBJECT, HOOK_TEMP_DIR, get_json_hook)

PREFIX = "created_by_hook-{}".format(sys.argv[0].split('/')[-1])
HOOK_JSON = get_json_hook()

# Windows information
HOST = "10.12.211.107" #windows
USER = "Administrator"
PORT = 22
PUBKEY = '/usr/share/foreman/.ssh/id_rsa'

# read the information received
hostname = HOOK_JSON.get('host').get('name').split('.')[0]
ip_addr = HOOK_JSON.get('host').get('ip')

#CMD = "Add-DnsServerResourceRecordA -Name {0}" \
#         " -ZoneName example.com -AllowUpdateAny -IPv4Address {1}" \
#         " -CreatePtr".format(hostname, ip_addr)


## troubleshooting command
CMD = "New-Item C:\{0}.txt -type file".format(hostname)

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, PORT, USER, key_filename=PUBKEY)

# via PowerShell
stdin, stdout, stderr = ssh.exec_command(CMD)
ssh.close()

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
        fd.file.write("stdout:      %s\n" % stdout.readlines())
        fd.file.write("stderr:      %s\n" % stderr.readlines())
        fd.file.flush()

sys.exit(0)
