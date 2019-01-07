#!/bin/bash

mkdir -p /var/local
SETUP_MARKER=/var/local/install_pbspro.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

touch $SETUP_MARKER
