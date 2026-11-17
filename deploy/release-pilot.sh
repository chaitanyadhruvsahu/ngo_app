#!/bin/sh
set -eu
sh /app/deploy/release.sh
python manage.py bootstrap_pilot
