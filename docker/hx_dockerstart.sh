#!/bin/bash

EXPORT PATH=$PATH:/app/haxall/bin

# If "var" is changed, the bind-mount in compose needs to change.
# Currently the volume's container location is "/app/haxall/var"
# EX: if "var" is changed to "demo" then the location should be "/app/haxall/demo"
# This volume is connected via bind-mounts, so is expected to exist on the local system. 
if [ ! -d "$1" ]; then
    fan hx init -headless var
fi

#needs the file location (i.e.)
fan hx run var