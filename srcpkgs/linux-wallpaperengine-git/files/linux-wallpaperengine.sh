#!/bin/sh

export LD_LIBRARY_PATH="/opt/linux-wallpaperengine/lib:$LD_LIBRARY_PATH"
exec /opt/linux-wallpaperengine/linux-wallpaperengine "$@"
