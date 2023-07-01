#!/bin/bash

#modified 2022.1.3

if [ $# -ne 3 ]; then
    echo "ERROR in number of parameters"
    echo "usage: routine.sh \"FNAME\" \"KPATH\" \"BANDSINPUT\" "
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the input file and pseudopotentials in the current directory.
FNAME="$1"
KPATH="$2" #e.g. routine.sh.kpath
BANDSINPUT="$3" #e.g. band.in

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"
BANDS_COMMAND="$PARA_PREFIX bands.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "bands command: $BANDS_COMMAND"
echo "kpath: $KPATH"
echo "bandsinput: $BANDSINPUT"
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
for INPUT in "${FNAME}.scf.in" "$KPATH" "$BANDSINPUT"
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
sed -e  "${TARGETLINE}a nbnd = $NBND" ${FNAME}.scf.in | sed "s/calculation.*/calculation = \'bands\'/" > ${FNAME}.nscf.in
TARGETLINE=$(($(sed -n '/K_POINTS/=' ${FNAME}.nscf.in)))
sed -e "${TARGETLINE},$((TARGETLINE+1))d" -e '/occupations.*/d' -e '/smearing.*/d' -e '/degauss.*/d' ${FNAME}.nscf.in > ${FNAME}.tmp.in
cat ${FNAME}.tmp.in $KPATH > ${FNAME}.nscf.in
rm ${FNAME}.tmp.in
echo "diff ${FNAME}.scf.in ${FNAME}.nscf.in:"
diff ${FNAME}.scf.in ${FNAME}.nscf.in
echo
#verify that nscf.in is generated as expected

#band calc.
echo "band calc. start"
$PW_COMMAND < ${FNAME}.nscf.in > ${FNAME}.nscf.out
$BANDS_COMMAND < $BANDSINPUT > ${FNAME}.band.out
echo "band calc. finished"
echo

#plotband.x < plotband.in
