#!/bin/sh
set -eu
[ "$#" = 1 ] || exit 2
case "$1" in
    status|learn-start|learn-next|learn-finish|close)
        exec /usr/libexec/heizungpanel/access.sh "$1"
        ;;
    *) exit 2 ;;
esac
