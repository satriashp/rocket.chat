#!/bin/bash

TIMESTAMP=$(date -u +"%Y%m%dT%H%MZ")
OUT="/data/backup-rocketchat-$TIMESTAMP"

mongodump --uri="$MONGO_URL" --gzip --archive="$OUT.archive.gz" --verbose
