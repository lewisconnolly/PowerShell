#!/usr/bin/python
#   Copyright 2016 Michael Rice <michael@michaelrice.org>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

from __future__ import print_function
import os
import ssl
import sys
import requests

# This is where VMWare keeps the pyVmomi and other libraries
sys.path.extend(os.environ['VMWARE_PYTHON_PATH'].split(';'))

from pyVim import connect
from pyVmomi import vim
requests.packages.urllib3.disable_warnings()
# this is to ignore SSL verification which is helpful for self signed certs
try:
    _create_unverified_https_context = ssl._create_unverified_context
except AttributeError:
    # Legacy Python that doesn't verify HTTPS certificates by default
    pass
else:
    # Handle target environment that doesn't support HTTPS verification
    ssl._create_default_https_context = _create_unverified_https_context
USER_NAME = "administrator@vsphere.local"
PASSWORD = ""
HOST = "10.39.0.40"
PORT = "443"
service_instance = connect.SmartConnect(host=HOST,
                                        user=USER_NAME,
                                        pwd=PASSWORD,
                                        port=int(PORT))

root_folder = service_instance.content.rootFolder
# again crude example here. use the logging module instead
with open("/var/log/alarmvars.txt", 'a') as f:
    print(root_folder.name, file=f)
    for var, val in os.environ.items():
        # When an alarm is triggered and run a lot of environment variables are set. 
        # This will list them all with their values.
        if var.startswith("VMWARE_ALARM"):
            print("{} = {}".format(var, val), file=f)
    print("##########", file=f)
connect.Disconnect(service_instance)