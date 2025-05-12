#!/bin/bash

set -eux

function print_usage()
{
    echo "Usage: ${0} [mode] [firmware|firmware_directory] [brand]"
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

# Import the config and utility functions
if [ -e ./firmport.config ]; then
    source ./firmport.config
else
    echo "Error: Could not find config file"
    echo "Please run the script from the root directory of the project"
    exit 1
fi

if [ -e ./utility.sh ]; then
    source ./core/utility.sh
else
    echo "Error: Could not find utility file"
    echo "Please run the script from the root directory of the project"
    exit 1
fi

BRAND=${2}

# Check connectivity with the database
if ! check_db_connection; then
    print_msg fail "Could not connect to the database"
    exit 1
fi

function emulate()
{
    print_msg info "${1} emulation started"
    FRIMWARE_FILE=${1}
    FILENAME=`basename ${FRIMWARE_FILE%.*}`

    if [ ${BRAND} = "auto" ]; then
        BRAND=`get_brand ${FRIMWARE_FILE}`
        if [ ! "${BRAND}" = "unknown" ]; then
            print_msg info "Identified brand: ${BRAND}"
        fi
    fi
    
    if [ "${BRAND}" = "unknown" ]; then
        print_msg warn "Unknown brand for ${FILENAME}. Cannot apply brand-specific arbitrations"
        BRAND_ARG=""
    else
        BRAND_ARG="-b ${BRAND}"
    fi

    # ================================
    # extract filesystem from firmware
    # ================================
    t_start="$(date -u +%s.%N)"

    timeout --preserve-status --signal SIGINT 300 \
        ${PYTHON_EXEC} ${ROOT_DIR}/sources/extractor/extractor.py \
        ${BRAND_ARG} \
        -sql ${PSQL_IP} \
        -nk \
        ${FRIMWARE_FILE} \
        ${IMAGES_DIR} 2>&1 >/dev/null

    if [ $? -ne 0 ] || [! -e ${}];  then
        print_msg fail "Extractor failed for ${FRIMWARE_FILE}"
        return
    fi

    IID=`${PYTHON_EXEC} ${ROOT_DIR}/python/util.py get_iid ${PSQL_IP} ${FRIMWARE_FILE} `

    if [ ! "${IID}" ]; then
        print_msg fail "Extractor failed to get IID for ${FRIMWARE_FILE}"
        return
    fi

    # ================================
    # extract kernel from firmware
    # ================================
    # If the brand is not specified in the argument, it will be inferred 
    # automatically from the path of the image file.

    timeout --preserve-status --signal SIGINT 300 \
        ${PYTHON_EXEC} ${ROOT_DIR}/sources/extractor/extractor.py \
        ${BRAND_ARG} \
        -sql ${PSQL_IP} \
        -np \
        ${FRIMWARE_FILE} \
        ${IMAGES_DIR} 2>&1 >/dev/null

    if [ $? -ne 0 ]; then
        print_msg fail "Extractor failed for ${FRIMWARE_FILE}"
        return
    fi

    WORK_DIR=`get_scratch ${IID}`
    mkdir -p ${WORK_DIR}
    chown -R ${USER}:${USER} ${WORK_DIR}
    echo ${FILENAME} > ${WORK_DIR}/name
    echo ${BRAND} > ${WORK_DIR}/brand
    sync

    print_msg success "Extractor completed for ${FRIMWARE_FILE} in $(echo "$(date -u +%s.%N) - ${t_start}" | bc) seconds"
    echo "$(date -u +%s.%N) - ${t_start}" | bc > ${WORK_DIR}/time_extract 

    # ================================
    # check architecture
    # ================================

}

FIRMWARE=${3}

if [ ! -d ${FIRMWARE} ]; then
    emulate ${FIRMWARE}
else
    FIRMWARES=`find ${3} -type f`

    for FIRMWARE in ${FIRMWARES}; do
        if [ ! -d "${FIRMWARE}" ]; then
            emulate${FIRMWARE}
        fi
    done
fi