#!/bin/bash

# Check if verbosity is requested
if [[ $1 == "-verbose" ]]; then
    VERBOSE=true
fi

#################
# Add some colour
#################
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    # Enables a Verbose Logging mode
    if [[ $VERBOSE ]]; then
        "${@:1}" && printf "\n${GREEN}Step completed successfully\n" || printf "\n${RED}Step Failed\n"
    else 
        "${@:1}" >/dev/null 2>&1 && printf "${GREEN}Success\n" || printf "${RED}Failed\n"
    fi
}

printf "Rebuilding arm config (requires elevation)"
log sudo udevadm control --reload-rules