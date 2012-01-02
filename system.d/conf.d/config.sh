#
# Main config script for bc-build.
# edit this file to set up releases, projects, etc.

LOG_LEVEL="INFO"
RELEASES_ROOT=/local/buddycloud/buddycloud-build/releases.d
unset RELEASES; declare -A RELEASES
RELEASES=([dev]="(web-client node-server python-server)"
	  [stable]="(web-client node-server)" )
