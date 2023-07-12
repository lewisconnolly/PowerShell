#!/usr/bin/python

import atexit
import argparse
import getpass
import logging
import os
import socket
import subprocess
import sys
import time
import urllib
import urllib2
import contextlib

sys.path.extend(os.environ['VMWARE_PYTHON_PATH'].split(';'))

from pyVim import connect
from pyVmomi import vim
from pyVmomi import vmodl
from urlparse import urlparse

def get_args():
    """Get command line args from the user.
    """
    parser = argparse.ArgumentParser(
        description='Standard Arguments for talking to vCenter')

    parser.add_argument('-s', '--host',
                        #required=True,
                        default='localhost',
                        action='store',
                        help='Remote host to connect to')
    parser.add_argument('-o', '--port',
                        type=int,
                        default=443,
                        action='store',
                        help='Port to connect on')

    parser.add_argument('-u', '--user',
                        #required=True,
                        default='administrator@vsphere.local',
                        action='store',
                        help='User name to use when connecting to host')

    parser.add_argument('-p', '--password',
                        #required=False,
                        default='6Rf-&XW]CG4,qTE-',
                        action='store',
                        help='Password to use when connecting to host')

    parser.add_argument('-f', '--filepath',
                        default="/storage/log",
                        action='store',
                        help='Path on the VCSA to store vm-support files')

    args = parser.parse_args()

    if not args.password:
        args.password = getpass.getpass(
            prompt='Enter SSO Admin password: ')

    return args

def main():
  """
  Simple pyvmomi (vSphere SDK for Python) script that sends vCenter Alarms to remote server
  """

  # Logger for storing vCenter Alarm logs 
  vcAlarmLog = logging.getLogger('vcenter_alarms')
  vcAlarmLog.setLevel(logging.INFO)
  vcAlarmLogFile = os.path.join('/var/log', 'vcenter_alarms.log')
  formatter = logging.Formatter("%(asctime)s;%(levelname)s;%(message)s","%Y-%m-%d %H:%M:%S") 
  vcAlarmLogHandler = logging.FileHandler(vcAlarmLogFile)
  vcAlarmLogHandler.setFormatter(formatter)
  vcAlarmLog.addHandler(vcAlarmLogHandler)
  vcAlarmLog.propagate = False

  args = get_args()
  si = None
  try:
	 si = connect.SmartConnect(host=args.host,
			user=args.user,
			pwd=args.password,
			port=int(args.port))
  except IOError, e:
	pass
  if not si:
	 vcAlarmLog.info("Could not connect to the specified host using specified username and password")
	 print "Could not connect to the specified host using specified username and password"
	 return -1

  atexit.register(connect.Disconnect, si)

  content = si.RetrieveContent()
  
  script = 'C:\Users\lewisc\Documents\AlertScripts\AlertCreator.ps1 '
  #command = 'powershell.exe -file ' + script
  
  for var, val in os.environ.items():
	 if var.startswith("VMWARE_ALARM"):
		vcAlarmLog.info(var + '=' + val)
		script += '-{} "{}" '.format(var[13:],val)
  
  contents = urllib.urlopen("http://10.39.2.69:8888/?command={}".format(script)).read()
	
  vcAlarmLog.info(script)
  vcAlarmLog.info(contents)

# Start program
if __name__ == "__main__":
    main()
