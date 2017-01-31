#!/usr/bin/env python
# vim:ts=4:sw=4:et
import os
import re
import sys
import requests
import urllib3
import tempfile

sys.path.append('/usr/share/foreman/config')

from hook_functions import \
  (HOOK_EVENT, HOOK_OBJECT, HOOK_TEMP_DIR, get_json_hook)

# hook definitions
PREFIX = "created_by_hook-{}".format(sys.argv[0].split('/')[-1])
HOOK_JSON = get_json_hook()

# satellite API queries
USERNAME = 'admin'
PASSWORD = 'redhat00'
BASE_URL = 'https://sat6mmello.usersys.redhat.com/api/{0}'

# tftp macros
TFTP_PXELINUX_ROOT_CFG="/var/lib/tftpboot/pxelinux.cfg"
TFTP_GRUB_ROOT_CFG="/var/lib/tftpboot/boot/grub2/powerpc-ieee1275"
TFTP_GRUB_CFG_PREFIX="grub.cfg-"
GRUB2_TEMPLATE="""
set default=0
set timeout=5
menuentry 'Install Red Hat Enteprise Linux for Power' {
 linux KERNEL_HERE BOOT_PARAM ip=IP_CMD::GW_CMD:NETMASK_CMD:HOSTNAME_CMD:NIC_CMD:none nameserver=DNS_CMD
 initrd INITRD_HERE
}
"""

def grab_all_pxelinux_configs(directory=TFTP_PXELINUX_ROOT_CFG):
    tftp_files = []
    mac_format = re.compile(ur'((?:(\d{1,2}|[a-fA-F]{1,2}){2})(?::|-*)){6}')
    for f in os.listdir(directory):
        if re.findall(mac_format, f):
            tftp_files.append(f)
    return tftp_files

def file_exists(cfg_file):
    if os.path.isfile(cfg_file):
        return True
    return False


def subnet_details(subnet_id, organization_id):
    s = requests.Session()
    s.auth = (USERNAME,PASSWORD)
    scope = "organizations/{0}/subnets".format(organization_id)
    req = s.get(BASE_URL.format(scope), verify=False)
    if req.status_code == 200:
        data = req.json()['results']
        for m in data:
            if m.get('id') == subnet_id:
                dns_primary = m.get('dns_primary')
                network = m.get('network')
                gateway = m.get('gateway')

        return dns_primary, network, gateway
    return None

def process_pxelinux_cfg(tftp_files):
    content = None
    for f in tftp_files:
        fpath = os.path.join(TFTP_PXELINUX_ROOT_CFG, f)
        if file_exists(fpath):
            with open(fpath, mode='ro') as fd:
                content = fd.readlines()

        if content:
            for line in content:
                if "KERNEL" in line:
                    kernel_arg = line.split()[-1]
                    grub_aux = GRUB2_TEMPLATE.replace("KERNEL_HERE", kernel_arg)

                if "initrd" in line:
                    initrd_arg = line.split()[1].split('=')[-1]
                    boot_arg = line.split()[-3:]
                    boot_arg = ' '.join(boot_arg).replace('network', '').replace('ks.sendmac', '')
                    grub_aux = grub_aux.replace("INITRD_HERE", initrd_arg)
                    grub_aux = grub_aux.replace("BOOT_PARAM", boot_arg)

            # read the information received
            if HOOK_JSON.get('host'):
                hostname = HOOK_JSON.get('host').get('name', None)
                if hostname:
                    grub_aux = grub_aux.replace("HOSTNAME_CMD", hostname)

                if HOOK_JSON.get('host').get('interfaces'):
                    for eth in HOOK_JSON.get('host').get('interfaces'):
                        if eth.get('provision'):
                            nic = eth.get('identifier')
                            ip = eth.get('ip')
                    if ip:
                        grub_aux = grub_aux.replace("IP_CMD", ip)

                    if nic:
                        grub_aux = grub_aux.replace("NIC_CMD", nic)

                try:
                    dns_primary, network, gateway = subnet_details(
                                                                   HOOK_JSON.get('host').get('subnet_id'),
                                                                   HOOK_JSON.get('host').get('organization_id'))
                    grub_aux = grub_aux.replace("DNS_CMD", dns_primary )
                    grub_aux = grub_aux.replace("NETMASK_CMD", network)
                    grub_aux = grub_aux.replace("GW_CMD", gateway)
                except:
                    pass

            filename = os.path.join(TFTP_GRUB_ROOT_CFG, str(TFTP_GRUB_CFG_PREFIX + f))
            with open(filename, 'w') as grub_cfg:
                grub_cfg.write(grub_aux)

# calls script
pxefiles = grab_all_pxelinux_configs()
process_pxelinux_cfg(pxefiles)


# for troubleshooting purposes, you can save the received data to a file
# to parse the information to be used on the trigger.
# To accomplish it, set the variable dumpdata to True
dumpdata = True
if dumpdata:
    with tempfile.NamedTemporaryFile(dir=HOOK_TEMP_DIR,
                                     delete=False,
                                     prefix=PREFIX) as fd:
        fd.file.write("HOOK_OBJECT: %s\n" % HOOK_OBJECT)
        fd.file.write("HOOK_EVENT:  %s\n" % HOOK_EVENT)
        fd.file.write("HOOK_JSON:   %s\n" % HOOK_JSON)

        # local variables
        fd.file.flush()

sys.exit(0)
