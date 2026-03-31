#!/bin/bash
# Start the Dell iDRAC service driver helper.
# Required for local racadm commands to communicate with iDRAC hardware.
# This service loads kernel modules and sets up the communication channel
# between the host OS and the iDRAC BMC. Without it, local racadm will fail.
# Safe to run in remote-only mode — it will exit silently if no hardware is present.

if [ -x /usr/libexec/instsvcdrv-helper ]; then
  /usr/libexec/instsvcdrv-helper start 2>/dev/null || true
fi

exec "$@"
