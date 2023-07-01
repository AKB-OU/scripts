#!/bin/bash

#modified 2022.1.2

if [ $# -ne 5 ]; then
    echo "ERROR in number of parameters"
    echo "usage: conv_k.sh \"FNAME\" \"KSTART\" \"KEND\" \"KINTERV\" \"KSHIFT\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
KSTART="$2"
KEND="$3"
KINTERV="$4"
KSHIFT="$5"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"

echo "we sweep from ${KSTART}x${KSTART}x${KSTART} to ${KEND}x${KEND}x${KEND} with interval of $KINTERV and Gamma-shift = $KSHIFT"
TARGETLINE=$(($(sed -n '/K_POINT/=' ${FNAME}.scf.in) + 1))

for ((KMESH=$KSTART; KMESH<=$KEND; KMESH+=$KINTERV))
do
    sed -e "${TARGETLINE}a $KMESH $KMESH $KMESH $KSHIFT $KSHIFT $KSHIFT" ${FNAME}.scf.in | sed -e "${TARGETLINE}d" > ${FNAME}_k${KMESH}.scf.in
    $PW_COMMAND < ${FNAME}_k${KMESH}.scf.in > ${FNAME}_k${KMESH}.scf.out
    #echo "k${KMESH}: $(grep -a "^\!" ${FNAME}_k${KMESH}.scf.out)"
    echo "${KMESH} $(awk '/^\!/ {print $5}' ${FNAME}_k${KMESH}.scf.out)"
done
