#!/bin/bash
apt update;
apt -y install curl;
curl -v http://docservice:8000/internal/cluster/inactive -X PUT -s -o /dev/null; 

FILES_DIR=/var/lib/onlyoffice/documentserver/App_Data/cache/files/
for ENTRY in `ls $FILES_DIR`; do
  if [ "$ENTRY" != "errors" ]; then
    if [ "$ENTRY" != "forgotten" ]; then
      rm -rfv $FILES_DIR$ENTRY
    fi
  fi
done


PGPASSWORD=$DB_PWD psql --host=postgresql --user=postgres --file=/sql/removetbl/removetbl.sql;
PGPASSWORD=$DB_PWD psql --host=postgresql --user=postgres --file=/sql/createdb/createdb.sql;

echo work done
