# Utilities for hook scripts, used with foreman_hooks
#
# Source this at the start of any bash hook script:
#
#   . hook_functions.sh
#
# It reads in a JSON representation of the object and then provides a
# hook_data wrapper around jgrep to read fields from it, e.g.
#
#   hostname=$(hook_data host.name)
#   comment=$(hook_data host.comment)

# update, create, before_destroy etc.
HOOK_EVENT=$1
# to_s representation of the object, e.g. host's fqdn
HOOK_OBJECT=$2

HOOK_OBJECT_FILE=$(mktemp -t foreman_hooks.XXXXXXXXXX)
trap "rm -f $HOOK_OBJECT_FILE" EXIT
cat > $HOOK_OBJECT_FILE

hook_data() {
  if [ $# -eq 1 ]; then
    jgrep -s "$1" < $HOOK_OBJECT_FILE
  else
    jgrep "$*" < $HOOK_OBJECT_FILE
  fi
}
