#!/bin/bash

#modified 2023.1.22

if [ $# -ne 8 ]; then
    echo "ERROR in number of parameters"
    echo "usage: amr.sh \"WTINPUT\" \"MU (e.g. 0.00)\" \"T (e.g. 10.00)\" \"phi (angle from x, fixed)\" \"theta_start\" \"theta_end\" \"theta_del\" \"SUFFIX\""
    exit 1
fi

WTINPUT="$1"
MU="$2"
T="$3"
PHI="$4"
THETA_S="$5"
THETA_E="$6"
THETA_D="$7"
SUFFIX="$8"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
WT_COMMAND="$PARA_PREFIX wt.x"

echo "current directory: $CURRENT_DIR"
echo "wt command: $WT_COMMAND"
echo "input: $WTINPUT"
echo "mu: $MU"
echo "T: $T"
echo "phi: $PHI"
echo "theta_s: $THETA_S"
echo "theta_e: $THETA_E"
echo "theta_d: $THETA_D"
echo "suffix: $SUFFIX"
echo "we sweep polar angle (theta) from $THETA_S deg to $THETA_E deg at intervals of $THETA_D deg"
echo "we fix azimuthal angle (phi) at $PHI deg"
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

#output format = CORENAME_${DEG}deg.dat
#expected in python scripts

for ((DEG=$THETA_S; DEG<=$THETA_E; DEG+=$THETA_D))
do
    sed "s/Btheta.*/Btheta = $DEG, Bphi = $PHI/" $WTINPUT > wt.in

    echo "diff $WTINPUT wt.in:"
    diff $WTINPUT wt.in
    
    $WT_COMMAND
    
    TARGETLINE=$(($(sed -n '/SELECTEDBANDS/=' $WTINPUT)+1))
    echo "target line = $TARGETLINE"
    NBND=$(sed -n ${TARGETLINE}p $WTINPUT)
    echo "nbnd = $NBND"
    for J in $(seq 1 $NBND)
    do
	BNDINDEX=$(sed -n $((${TARGETLINE}+1))p $WTINPUT | awk "{print \$$J}")
	echo "bndindex = $BNDINDEX"
	mv -f sigma_band_${BNDINDEX}_mu_${MU}eV_T_${T}K.dat sigma_band_${BNDINDEX}_mu_${MU}eV_T_${T}K_${SUFFIX}_${DEG}deg.dat
	mv -f sigma_kz_band_${BNDINDEX}_mu_${MU}eV_T_${T}K.dat sigma_kz_band_${BNDINDEX}_mu_${MU}eV_T_${T}K_${SUFFIX}_${DEG}deg.dat
    done
    mv -f WT.out WT_${SUFFIX}_${DEG}deg.out
    echo "$DEG deg finished."
    echo
done
