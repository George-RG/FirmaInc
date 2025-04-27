#!/bin/bash

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
        *)
            echo "[?] $msg"
            ;;
    esac
}