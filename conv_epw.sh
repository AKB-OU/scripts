#!/bin/bash

#modified 2022.1.2

if [ $# -ne 5 ]; then
    echo "ERROR in number of parameters"
    echo "usage: conv_k.sh \"FNAME\" \"KSTART\" \"KEND\" \"KINTERV\" \"FLAG\""
    exit 1
fi

#we assume that input file name is "$FNAME"
#please make preprocess in EPW.
FNAME="$1"
KSTART="$2"
KEND="$3"
KINTERV="$4"
FLAG="$5"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
POST_PREFIX="-npool $((P_CPU*CORES))"
EPW_COMMAND="$PARA_PREFIX ~/qe/qe-7.0/EPW/bin/epw.x $POST_PREFIX"

echo "current directory: $CURRENT_DIR"
echo "epw command: $EPW_COMMAND"

echo "you celected ${FLAG}-mesh convergence test mode"
echo "we sweep from ${KSTART}x${KSTART}x${KSTART} to ${KEND}x${KEND}x${KEND} with interval of $KINTERV"
echo
#TARGETLINE=$(($(sed -n '/K_POINT/=' ${FNAME}.scf.in) + 1))

for ((KMESH=$KSTART; KMESH<=$KEND; KMESH+=$KINTERV))
do
    rm restart.fmt
    sed -e "s/n${FLAG}f1.*/n${FLAG}f1 = ${KMESH}/" -e "s/n${FLAG}f2.*/n${FLAG}f2 = ${KMESH}/" -e "s/n${FLAG}f3.*/n${FLAG}f3 = ${KMESH}/" ${FNAME} > ${FNAME}.${FLAG}${KMESH}
    echo "diff ${FNAME} ${FNAME}.${FLAG}${KMESH}:"
    diff ${FNAME} ${FNAME}.${FLAG}${KMESH}
    #$EPW_COMMAND < ${FNAME}.${FLAG}${KMESH} > ${FLAG}${KMESH}.out
    mpirun -np $((P_CPU*CORES)) ~/qe/qe-7.0/EPW/bin/epw.x -npool $((P_CPU*CORES)) < ${FNAME}.${FLAG}${KMESH} > ${FLAG}${KMESH}.out
    
    grep "lambda :" ${FLAG}${KMESH}.out
    grep "lambda_tr :" ${FLAG}${KMESH}.out
    grep "logavg =" ${FLAG}${KMESH}.out
    grep "mu =   0.10 Tc" ${FLAG}${KMESH}.out

    grep "Fermi level (eV) =" ${FLAG}${KMESH}.out
    grep "DOS(states/spin/eV/Unit Cell) =" ${FLAG}${KMESH}.out
    grep "Electron smearing (eV) =" ${FLAG}${KMESH}.out
    grep "Fermi window (eV) =" ${FLAG}${KMESH}.out
    grep "Electron-phonon coupling strength =" ${FLAG}${KMESH}.out
    grep "Estimated Allen-Dynes Tc =" ${FLAG}${KMESH}.out
    grep "Estimated w_log in Allen-Dynes Tc =" ${FLAG}${KMESH}.out
    grep "Estimated BCS superconducting gap =" ${FLAG}${KMESH}.out
    
    echo "calculation ${FLAG}${KMESH} finished"
    echo
done
