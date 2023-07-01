#!/bin/bash

#modified 2022.1.6

if [ $# -ne 1 ]; then
    echo "ERROR in number of parameters"
    echo "usage: wtrun.sh \"WTINPUT\""
    exit 1
fi

WTINPUT="$1"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
WT_COMMAND="$PARA_PREFIX wt.x"

echo "current directory: $CURRENT_DIR"
echo "wt command: $WT_COMMAND"
echo "input: $WTINPUT"
echo

#find input
function FINDFILE () {
    FILENAME=$1
    FINDRESULT=$(find -maxdepth 1 -name $FILENAME)
    if [ "./$FILENAME" = "$FINDRESULT" ]; then
        echo "$FILENAME found"
    else
        echo "$FILENAME not found"
    fi
}
for INPUT in "$WTINPUT"
do
    FINDFILE "$INPUT"
    if [ "$(FINDFILE "$INPUT")" = "$INPUT not found" ]; then
        exit 1
    fi
done
echo

echo "calculation start"
cp $WTINPUT wt.in
$WT_COMMAND wt.x
echo "calculation finished"
echo
