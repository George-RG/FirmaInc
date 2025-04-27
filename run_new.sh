#!/bin/bash

set -eu

function print_usage()
{
    echo "Usage: ${0} [mode]... [brand] [firmware|firmware_directory]"
    echo "mode: use one option at once"
    echo "      -r, --run     : run mode         - run emulation (no quit)"
    echo "      -c, --check   : check mode       - check network reachable and web access (quit)"
    echo "      -a, --analyze : analyze mode     - analyze vulnerability (quit)"
    echo "      -d, --debug   : debug mode       - debugging emulation (no quit)"
    echo "      -b, --boot    : boot debug mode  - kernel boot debugging using QEMU (no quit)"
}

if [ $# -ne 3 ]; then
    print_usage ${0}
    exit 1
fi

function get_option()
{
    OPTION=${1}
    if [ ${OPTION} = "-c" ] || [ ${OPTION} = "--check" ]; then
        echo "check"
    elif [ ${OPTION} = "-a" ] || [ ${OPTION} = "--analyze" ]; then
        echo "analyze"
    elif [ ${OPTION} = "-r" ] || [ ${OPTION} = "--run" ]; then
        echo "run"
    elif [ ${OPTION} = "-d" ] || [ ${OPTION} = "--debug" ]; then
        echo "debug"
    elif [ ${OPTION} = "-b" ] || [ ${OPTION} = "--boot" ]; then
        echo "boot"
    else
        echo "none"
    fi
}

OPTION=`get_option ${1}`
if [ ${OPTION} == "none" ]; then
  print_usage ${0}
  exit 1
fi

# TODO: make this more robust
source ./utility.sh

function emulate()
{
    print_msg info "${1} emulation started"
    FRIMWARE_FILE=${1}
    
}