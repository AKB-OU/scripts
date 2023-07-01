#!/bin/bash

#!/bin/bash

#modified 2023.1.14

if [ $# -ne 4 ]; then
    echo "ERROR in number of parameters"
    echo "usage: conv_degauss.sh \"FNAME\" \"DSTART\" \"DEND\" \"DINTERV\""
    echo "NOTE: parameters are multiplied by 0.001."
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
DSTART="$2"
DEND="$3"
DINTERV="$4"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"

echo "we sweep from degauss = ${DSTART} to degauss = ${DEND} with interval of $DINTERV"

for ((DG=$DSTART; DG<=$DEND; DG+=$DINTERV))
do
    sed "s/degauss.*/degauss = ${DG}e-3/g" ${FNAME}.scf.in > ${FNAME}_d${DG}.scf.in
    $PW_COMMAND < ${FNAME}_d${DG}.scf.in > ${FNAME}_d${DG}.scf.out
    #echo "d${DG}: $(grep -a "^\!" ${FNAME}_d${DG}.scf.out)"
    echo "${DG} $(awk '/^\!/ {print $5}' ${FNAME}_d${DG}.scf.out)"
done
