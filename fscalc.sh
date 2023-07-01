#!/bin/bash

#modified 2023.1.23

if [ $# -ne 5 ]; then
    echo "ERROR in number of parameters"
    echo "usage: fscalc.sh \"FNAME\" \"FSINPUT\" \"nk1\" \"nk2\" \"nk3\""
    exit 1
fi

#we assume that scf calculation has already been done in the current directory.
#please prepare fs.in file in the current directory.
FNAME="$1"
FSINPUT="$2" #e.g. fs.in
NK1="$3"
NK2="$4"
NK3="$5"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"
FS_COMMAND="$PARA_PREFIX fs.x"
FERMI_VELOCITY_COMMAND="$PARA_PREFIX fermi_velocity.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "fs command: $FS_COMMAND"
echo "fermi_velocity command: $FERMI_VELOCITY_COMMAND"
echo "kmesh: ${NK1}x${NK2}x${NK3}"
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
for INPUT in "${FNAME}.scf.in" "$FSINPUT"
do
    FINDFILE "$INPUT"
    if [ "$(FINDFILE "$INPUT")" = "$INPUT not found" ]; then
        exit 1
    fi
done
echo

#generate nscf.fs.in file
TARGETLINE=$(($(sed -n '/K_POINT/=' ${FNAME}.scf.in) + 1))
sed -e "${TARGETLINE}a $NK1 $NK2 $NK3 0 0 0" ${FNAME}.scf.in | sed -e "${TARGETLINE}d" | sed "s/calculation.*/calculation = \'nscf\'/" > ${FNAME}.tmp.in

NBND=$(awk '/Starting wfcs/ {print $4}' ${FNAME}.scf.out)
#NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
if [ "$NBND" = "random" ]; then
	NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
fi
TARGETLINE=$(($(sed -n '/\&system/=' ${FNAME}.tmp.in)))
sed -e  "${TARGETLINE}a nbnd = $NBND" ${FNAME}.tmp.in | sed "s/occupations.*/occupations = \'tetrahedra\'/" | sed /smearing.*/d | sed /degauss.*/d > ${FNAME}.nscf.fs.in

rm ${FNAME}.tmp.in

echo "diff ${FNAME}.scf.in ${FNAME}.nscf.fs.in:"
diff ${FNAME}.scf.in ${FNAME}.nscf.fs.in
echo

#nscf calc.
echo "nscf calc. start"
$PW_COMMAND < ${FNAME}.nscf.fs.in > ${FNAME}.nscf.fs.out
echo "nscf calc. finished"
echo

#fs calc.
echo "fs calc. start"
$FS_COMMAND < $FSINPUT > ${FNAME}.fs.out
echo "fs calc. finished"
echo

#fermi velocity calc.
echo "fermi velocity calc. start"
$FERMI_VELOCITY_COMMAND < ${FNAME}.nscf.fs.in > ${FNAME}.vfermi.out
echo "fermi velocity calc. finished"
echo
