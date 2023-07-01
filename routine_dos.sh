#!/bin/bash

#modified 2022.1.4

if [ $# -ne 5 ]; then
    echo "ERROR in number of parameters"
    echo "usage: routine_dos.sh \"FNAME\" \"DOSINPUT\" \"nk1\" \"nk2\" \"nk3\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
DOSINPUT="$2" #e.g. $FNAME.dos.in
NK1="$3"
NK2="$4"
NK3="$5"
#pdos.in is generated automatically from dos.in.

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"
DOS_COMMAND="$PARA_PREFIX dos.x"
PROJWFC_COMMAND="$PARA_PREFIX projwfc.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "dos command: $DOS_COMMAND"
echo "projwfc command: $PROJWFC_COMMAND"
echo "dosinput: $DOSINPUT"
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
for INPUT in "${FNAME}.scf.in" "$DOSINPUT"
do
    FINDFILE "$INPUT"
    if [ "$(FINDFILE "$INPUT")" = "$INPUT not found" ]; then
        exit 1
    fi
done
echo

#scf calc.
echo "scf calc. start"
$PW_COMMAND < ${FNAME}.scf.in > ${FNAME}.scf.out
echo "scf calc. finished"
echo "$(grep -a "the Fermi energy" ${FNAME}.scf.out)"
echo "$(grep -a "^\!" ${FNAME}.scf.out)"
echo

#make nscf.in
NBND=$(awk '/Starting wfcs/ {print $4}' ${FNAME}.scf.out)
#NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
if [ "$NBND" = "random" ]; then
	NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
fi
TARGETLINE=$(($(sed -n '/\&system/=' ${FNAME}.scf.in)))
sed -e  "${TARGETLINE}a nbnd = $NBND" ${FNAME}.scf.in | sed "s/calculation.*/calculation = \'nscf\'/" | sed "s/occupations.*/occupations = \'tetrahedra\'/" | sed /smearing.*/d | sed /degauss.*/d > ${FNAME}.nscf.in

TARGETLINE=$(($(sed -n '/K_POINT/=' ${FNAME}.nscf.in) + 1))
sed -e "${TARGETLINE}a $NK1 $NK2 $NK3 0 0 0" ${FNAME}.nscf.in | sed -e "${TARGETLINE}d" > ${FNAME}.tmp.in
mv ${FNAME}.tmp.in ${FNAME}.nscf.in
echo "diff ${FNAME}.scf.in ${FNAME}.nscf.in:"
diff ${FNAME}.scf.in ${FNAME}.nscf.in
echo
#verify that nscf.in is generated as expected

#nscf calc.
echo "nscf calc. start"
$PW_COMMAND < ${FNAME}.nscf.in > ${FNAME}.nscf.out
echo "nscf calc. finished"
echo

#dos calc.
echo "dos calc. start"
$DOS_COMMAND < $DOSINPUT > ${FNAME}.dos.out
echo "dos calc. finished"
echo

#make pdos.in file
sed "s/\&dos/\&projwfc/" $DOSINPUT | sed "s/fildos.*/filpdos = \'${FNAME}\'/" > ${FNAME}.pdos.in
echo "diff $DOSINPUT ${FNAME}.pdos.in:"
diff $DOSINPUT ${FNAME}.pdos.in
echo
#verify that pdos.in is generated as expected

#pdos calc.
echo "pdos calc. start"
$PROJWFC_COMMAND < ${FNAME}.pdos.in > ${FNAME}.pdos.out
echo "pdos calc. finished"
echo
