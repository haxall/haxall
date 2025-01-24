#!/bin/bash

export PATH=$PATH:/app/haxall/bin
echo "$DB_NAME"

# This volume is connected via bind-mount. The bind-mount, under volumes in the compose file, will create the folder on local system if it doesn't exist. 
# The bind-mount is /app/haxall/dbs and locally is referred to as "dbs"
# The following creates the bind-mount folder if it doesn't exist, and cd's into it.
if [ -d "dbs" ]; then
    cd dbs
else
    mkdir dbs
    cd dbs
fi

init_db () {
  if [ -n "$HAXALL_ROOT_USER" ]; do
    fan hx init -headless "$DB_NAME" -suUser "${HAXALL_ROOT_USER:-su}" -suPass "${HAXALL_ROOT_PASSWORD}"
  else
    fan hx init -headless "$DB_NAME"
}

# The following runs hx init with the given database name from build argument DB_NAME (default is "var").
# It can be changed when doing docker compose commands like so: --build-arg DB_NAME=example
# It is stored under an ENV variable of same name (BD_NAME) created during the dockerfile build context, and persists after. 
if [ -d "$DB_NAME" ]; then
    # The directory exists, but is EMPTY. 
    if [ -z "$(ls -A "$DB_NAME")" ]; then
        echo "$DB_NAME is empty, running hx init..."
        init_db
    # The directory exists, and is NOT empty.
    else
        echo "$DB_NAME already exists." && echo "If you want to modify your superuser account or the HTTP port, run the 'fan hx init' command again on the same directory, like so:" && echo "fan hx init $DB_NAME"
    fi
# The directory does not exist.
else
    echo "$DB_NAME does not exist, running hx init..."
    init_db
fi

# This runs haxall after creating the database. Any errors here are likely caused by the bind-mounted database being edited on the local file system by the host. 
# Command "hx run" needs the file location of the database (i.e. /app/haxall/dbs/$DB_NAME)
fan hx run "$DB_NAME"