#!/bin/sh
set -eu

if [ "${RUN_WORKERS:-true}" = true ]; then
    cp /run/supervisor/supervisord.conf /run/lotusboard-workers.conf
    # Allow running jobs to finish when switching containers.
    sed -i '/^\[program:/a stopasgroup=true\nkillasgroup=true\nstopwaitsecs=120' /run/lotusboard-workers.conf
else
    : > /run/lotusboard-workers.conf
fi

if [ "${RUN_SCHEDULER:-true}" = true ]; then
    # BusyBox accepts the legacy file without a final newline; Debian cron does not.
    { cat /etc/crontabs/root; printf '\n'; } | crontab -
fi

exec "$@"
