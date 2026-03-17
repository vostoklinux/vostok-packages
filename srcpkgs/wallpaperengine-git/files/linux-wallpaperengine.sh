#!/bin/sh

export LD_LIBRARY_PATH="/opt/linux-wallpaperengine:/opt/linux-wallpaperengine/lib64:$LD_LIBRARY_PATH"
exec /opt/linux-wallpaperengine/linux-wallpaperengine "$@"
