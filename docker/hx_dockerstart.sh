#!/bin/bash

export PATH=$PATH:/app/haxall/bin

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
    if [ -n "$HAXALL_SU_PASSWORD" ]; then
        fan hx init -headless "$HAXALL_DB_NAME" -suUser "${HAXALL_SU_USERNAME:-su}" -suPass "${HAXALL_SU_PASSWORD}"
    else
        fan hx init -headless "$HAXALL_DB_NAME"
    fi
}

# The directory exists
if [ -d "$HAXALL_DB_NAME" ]; then
    # The directory exists, but is EMPTY.
    if [ -z "$(ls -A "$HAXALL_DB_NAME")" ]; then
        echo "$HAXALL_DB_NAME is empty, running hx init..."
        init_db
    # The directory exists, and is NOT empty.
    else
        echo "$HAXALL_DB_NAME already exists so not running init..."
    fi
# The directory does not exist
else
    echo "$HAXALL_DB_NAME does not exist, running hx init..."
    init_db
fi

# This runs haxall after creating the database. Any errors here are likely caused by the bind-mounted database being edited on the local file system by the host.
# Command "hx run" needs the file location of the database (i.e. /app/haxall/dbs/$HAXALL_DB_NAME)
fan hx run "$HAXALL_DB_NAME"
