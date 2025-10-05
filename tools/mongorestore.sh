#!/bin/bash

LATEST=$(ls -t /data/backup-rocketchat-*.archive.gz | head -n 1)
mongorestore --uri="$MONGO_URL" --gzip --archive="$LATEST" --drop --verbose
