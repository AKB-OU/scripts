#!/bin/bash

#modified 2022.1.2

if [ $# -ne 4 ]; then
    echo "ERROR in number of parameters"
    echo "usage: conv_k.sh \"FNAME\" \"KSTART\" \"KEND\" \"KINTERV\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
KSTART="$2"
KEND="$3"
KINTERV="$4"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"
PH_COMMAND="$PARA_PREFIX ph.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "ph command: $PH_COMMAND"

echo "we sweep from ${KSTART}x${KSTART}x${KSTART} to ${KEND}x${KEND}x${KEND} with interval of $KINTERV"
echo "we use gamma-shifted MP grid"
echo "we assume a file 'ph.in' with fildyn='FNAME.dyn'"

TARGETLINE=$(($(sed -n '/K_POINT/=' ${FNAME}.scf.in) + 1))

for ((KMESH=$KSTART; KMESH<=$KEND; KMESH+=$KINTERV))
do
    sed -e "${TARGETLINE}a $KMESH $KMESH $KMESH 1 1 1" ${FNAME}.scf.in | sed -e "${TARGETLINE}d" > ${FNAME}_k${KMESH}.scf.in
    $PW_COMMAND < ${FNAME}_k${KMESH}.scf.in > ${FNAME}_k${KMESH}.scf.out
    echo "k${KMESH}: "
    echo "$(grep -a "^\!" ${FNAME}_k${KMESH}.scf.out)"
    echo ""
    $PH_COMMAND < ph.in > ${FNAME}_k${KMESH}.ph.out
    cp ${FNAME}.dyn ${FNAME}_k${KMESH}.dyn 
done
