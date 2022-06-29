#!/bin/bash

# Global return variable
_returnVar=""

resetReturnVar() {
    _returnVar=""
}

checkSudoRights() {
    [ "$EUID" -ne 0 ] && printError "This script must be run as root" && exit 1
}

checkNoError() {
    if [ "$1" -ne 0 ]; then
        curl -sS --data-raw "$2" "$PINGURL"/fail
        printError "$2"
        _returnVar="error"
    else
        printSuccess "$2"
        _returnVar="success"
    fi
}

printHelper() {
    printf "\n$1 ($(date +'%F %T')) %-10s: $3\n" "$2"
}

printError() {
    printHelper "🔴" "ERROR" "$1"
}

printInfo() {
    printHelper "🔵" "INFO" "$1"
}

printSuccess() {
    printHelper "🟢" "SUCCESS" "$1"
}

printImportant() {
    printf "\n"
    for i in {0..20}
    do
        printf "#"
    done
    printf "\n"
    printHelper "🔶" "IMPORTANT" "$1"
}
