#!/usr/bin/bash

function usage()
{
    echo "Running the script $(basename $0) will look in the current directory for a valid filename with a proper extension. It will then compile and execute the file."
    echo ""
    echo "    -i filename"
    echo "        Redirects input from filename to execution of the file."
}

function ParseArguments
{
    while getopts ":hi:" arg; do
        case "${arg}" in
            h)
                usage
                exit 0
                ;;
            i)
                inputFilename=${OPTARG}
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done
}

function GetFileNames()
{
    fileNames=($(ls))
    if [ ${#fileNames[@]} -eq 0 ]; then
        return 1
    else
        return 0
    fi

}

function GetFileExtension()
{
    local __result=$1
    eval $__result="${2##*.}"
}

function IsValidFileExtension()
{
    case "$1" in
        "cc" | "cpp" | "c")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function GetFileName()
{
    local __result=$1
    eval $__result="${2%.*}"
}

function FindValidFileName()
{
    local __result=$1
    local myResult=""

    for fileName in "${fileNames[@]}"
    do
        :
            GetFileExtension extension $fileName
            IsValidFileExtension $extension
            if [ $? -eq 0 ]; then
                myResult=$fileName
                break
            fi
    done

    eval $__result=$myResult
}

function CompileFile
{
    local __result=$2

    GetFileName fileName $1

    echo "g++ -std=c++11 $1 -o $fileName"
    g++ -std=c++11 $1 -o $fileName
    if [ $? -ne 0 ]; then
        return 1
    fi

    eval $__result=$fileName
}

function MakeFile()
{
    echo "Going to make: $1" 
    make $1
    if [ $? -ne 0 ]; then
        return 1
    fi
}

function ExecuteFile()
{
    if [[ ! -z $inputFilename ]]; then
        ./$1 < "$inputFilename"
        if [ $? -ne 0 ]; then
            return 1
        fi
    else
        ./$1
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
}

function main()
{
    ParseArguments $@

    GetFileNames
    if [ $? -ne 0 ]; then
        echo "Failed to find any file names in the directory $(pwd)"
        echo "Usage: $(basename $0) -h"
        exit 1
    fi

    FindValidFileName validFileName
    if [[ -z "$validFileName" ]]; then
        echo "Failed to find a valid file name in: "$(ls)
        echo "Usage: $(basename $0) -h"
        exit 1
    fi

    CompileFile $validFileName outputFileName
    if [ $? -ne 0 ]; then
        exit 1
    fi

    ExecuteFile $outputFileName
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

main $@
