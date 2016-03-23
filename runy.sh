#!/usr/bin/bash

function usage()
{
    bold=$(tput bold)
    underline=$(tput smul)
    endUnderline=$(tput rmul)
    normal=$(tput sgr0)

    echo -e "\n${bold}USAGE:${normal}\n\t$(basename $0 .sh) [${bold}OPTIONS${normal}]\n"
    echo -e "${bold}DESCRIPTION:${normal}\n\tRunning the script ${bold}$(basename $0)${normal} will look in the current directory for a valid filename with a proper extension. It will then compile and execute the file.\n"
    echo -e "${bold}OPTIONS:${normal}\n"
    echo -e "\t${bold}-g${normal}"
    echo -e "\t\tAdds the debugger flag for compilation.\n"
    echo -e "\t${bold}-i${normal} ${underline}FILE${endUnderline}"
    echo -e "\t\tRedirects input from ${underline}FILE${endUnderline} to execution of the file.\n"
    echo -e "\t${bold}-O${normal} ${underline}NUM${endUnderline}"
    echo -e "\t\tSpecifies the optimization level.\n"
    echo -e "\t${bold}-t${normal} ${underline}NUM${endUnderline}"
    echo -e "\t\tRuns the program ${underline}NUM${endUnderline} times.\n"
}

function ParseArguments
{
    while getopts ":hi:t:O:g" arg; do
        case "${arg}" in
            i)
                inputFilename=${OPTARG}
                ;;
            t)
                timeIterationCount=${OPTARG}
                ;;
            O)
                optimizationLevel=${OPTARG}
                ;;
            h)
                usage
                exit 0
                ;;
            g)
                debuggerFlag=0
                ;;
            :)
                case "${OPTARG}" in
                    t)
                        timeIterationCount=1
                        ;;
                    *)
                        echo "$(basename $0 .sh): option requires an argument -- ${OPTARG}"
                        exit 1
                        ;;
                esac ;;
            \?)
                echo "$(basename $0 .sh): unknown option -- ${OPTARG}"
                exit 1
                ;;
        esac
    done

    ValidateCommandLineArguments
}

function ValidateCommandLineArguments
{
    if [ ! -z $inputFilename ]; then
        DoesFileExist $inputFilename
        if [ $? -eq 1 ]; then
            echo "$(basename $0 .sh): file does not exist -- $inputFilename"
            exit 1
        fi
    fi

    if [ ! -z $timeIterationCount ]; then
        IsValidTimeIterationCount $timeIterationCount
        if [ $? -eq 1 ]; then
            echo "$(basename $0 .sh): invalid option -- $timeIterationCount"
            exit 1
        fi
    fi

    if [ ! -z $optimizationLevel ]; then
        IsValidOptimizationLevel $optimizationLevel
        if [ $? -eq 1 ]; then
            echo "$(basename $0 .sh): invalid optimization level -- $optimizationLevel"
            exit 1
        fi
    fi

# TODO : -g flag should be incompatible with -O and -t flags so display an error and exit
}

function IsValidOptimizationLevel
{
    if [[ $1 -ge 0 ]] && [[ $1 -le 3 ]]; then
        return 0
    else
        return 1
    fi
}

function IsValidTimeIterationCount
{
    if [[ $1 =~ ^[-+]?[0-9]+$ ]] && [ $1 -gt 0 ]; then
        return 0
    else
        return 1
    fi
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

function GetModifyDate
{
    local __result=$1
    modifyDate=$(stat -c %Y $2)
    modifyDate=${modifyDate%% *}
    eval $__result=$modifyDate
}

function DoesFileExist
{
    if [ -f $1 ]; then
        return 0
    else
        return 1
    fi
}

function ShouldCompileFile
{
    DoesFileExist $2
    if [ $? -eq 0 ]; then
        GetModifyDate executableModifyDate $2
        GetModifyDate fileModifyDate $1

        if [ $executableModifyDate -gt $fileModifyDate ]; then
            return 1
        fi
    fi

    return 0
}

function CompileFile
{
    local __result=$2

    GetFileName fileName $1

    eval $__result=$fileName

    ShouldCompileFile $1 $fileName
    if [ $? -eq 1 ]; then
        echo "$(basename $0 .sh): '$fileName' is up to date."
        return 0
    fi

    toCompile="g++ -std=c++11 $1 -o $fileName -Wall"

    if [[ ! -z $optimizationLevel ]]; then
        toCompile="$toCompile -O$optimizationLevel"
    fi

    if [[ ! -z $debuggerFlag ]]; then
        toCompile="$toCompile -g"
    fi

    echo $toCompile
    eval $toCompile
    if [ $? -ne 0 ]; then
        return 1
    fi
}

function ExecuteFile()
{
    toExecute="./$1"

    if [[ ! -z $inputFilename ]]; then
        toExecute="$toExecute < $inputFilename"
    fi

    if [[ ! -z $timeIterationCount ]]; then
        toExecute="for i in {1..$timeIterationCount}; do time $toExecute; done"
    fi

    if [[ ! -z $debuggerFlag ]]; then
        toExecute="gdb $toExecute"
    fi

    eval $toExecute
    if [ $? -ne 0 ]; then
        return 1
    fi

    return 0
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
