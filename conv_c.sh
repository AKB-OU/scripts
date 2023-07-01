#!/bin/bash

#!/bin/bash

#modified 2022.1.3

if [ $# -ne 5 ]; then
    echo "ERROR in number of parameters"
    echo "usage: conv_c.sh \"FNAME\" \"CSTART\" \"CEND\" \"CINTERV\" \"CMULT\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
CSTART="$2"
CEND="$3"
CINTERV="$4"
CMULT="$5"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"

echo "we sweep from cutwfc = ${CSTART}, cutrho = $((CSTART*CMULT)) to cutwfc = ${CEND}, cutrho = $((CEND*CMULT)) with interval of $CINTERV"

for ((CUTWFC=$CSTART; CUTWFC<=$CEND; CUTWFC+=$CINTERV))
do
    CUTRHO=$((CUTWFC*CMULT))
    sed "s/cutwfc.*/cutwfc = $CUTWFC/g" ${FNAME}.scf.in | sed "s/cutrho.*/cutrho = $CUTRHO/g" > ${FNAME}_c${CUTWFC}.scf.in
    $PW_COMMAND < ${FNAME}_c${CUTWFC}.scf.in > ${FNAME}_c${CUTWFC}.scf.out
    #echo "c${CUTWFC}: $(grep -a "^\!" ${FNAME}_c${CUTWFC}.scf.out)"
    echo "${CUTWFC} $(awk '/^\!/ {print $5}' ${FNAME}_c${CUTWFC}.scf.out)"
done
