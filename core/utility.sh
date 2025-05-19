
print_msg() {
    local type=$1
    shift
    local msg=$*

    case "$type" in
        success)
            echo -e "[\033[1;32m+\033[0m] $msg"  # Green +
            ;;
        info)
            echo -e "[\033[1;34m+\033[0m] $msg"  # Blue +
            ;;
        fail)
            echo -e "[\033[1;31m✗\033[0m] $msg"  # Red ✗
            ;;
        warning)
            echo -e "[\033[1;33m!\033[0m] $msg"  # Yellow !
            ;;
        warn)
            echo -e "[\033[1;33m!\033[0m] $msg"  # Yellow !
            ;;
        *)
            echo "[?] $msg"
            ;;
    esac
}

function check_db_connection()
{
    if [ -z "${PSQL_IP}" ]; then
        echo "Error: PSQL_IP is not set"
        return 1
    fi

    $PYTHON_EXEC $ROOT_DIR/python/util.py check_db_connection ${PSQL_IP} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Could not connect to the database"
        return 1
    fi

    return 0
}

function get_brand()
{
  INFILE=${1}
  echo `$PYTHON_EXEC $ROOT_DIR/python/util.py get_brand ${PSQL_IP} ${INFILE} `
}

function check_is_number()
{
  if [ $# -ne 1 ]; then
    echo "Error: check_is_number() requires exactly one argument"
    return 1
  fi

  if ! [[ $1 =~ ^[0-9]+$ ]]; then
    echo "Error: $1 is not a number"
    return 1
  fi

  return 0
}

function get_scratch()
{
    if check_is_number "${1}"; then
        echo "Error: Invalid image number!"
        exit 1
    fi

    echo "${SCRATCH_DIR}/image-${1}"
}

function get_image_info()
{
    IID=${1}
    KEY=${2}

    if [ -z "${IID}" ] || [ -z "${KEY}" ]; then
        echo "Error: get_image_info() requires two arguments"
        return 1
    fi
    if ! check_is_number "${IID}"; then
        echo "Error: Invalid image number!"
        return 1
    fi

    SCRATCH_DIR=$(get_scratch ${IID})

    echo `$PYTHON_EXEC $ROOT_DIR/python/imageInfo.py $SCRATCH_DIR -g -k ${KEY} `

    if [ $? -ne 0 ]; then
        echo "Error: Failed to get image info for ${IID}"
        return 1
    fi
}

function set_image_info()
{
    IID=${1}
    KEY=${2}
    VALUE=${3}

    if [ -z "${IID}" ] || [ -z "${KEY}" ] || [ -z "${VALUE}" ]; then
        echo "Error: set_image_info() requires three arguments"
        return 1
    fi
    if ! check_is_number "${IID}"; then
        echo "Error: Invalid image number!"
        return 1
    fi

    SCRATCH_DIR=$(get_scratch ${IID})

    echo `$PYTHON_EXEC $ROOT_DIR/python/imageInfo.py $SCRATCH_DIR -s -k ${KEY} -v ${VALUE}`

    if [ $? -ne 0 ]; then
        echo "Error: Failed to set image info for ${IID}"
        return 1
    fi
}