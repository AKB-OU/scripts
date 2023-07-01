#!/bin/bash

#modified 2022.1.3

if [ $# -ne 4 ]; then
    echo "ERROR in number of parameters"
    echo "usage: routine_wannier.sh \"FNAME\" \"NK1\" \"NK2\" \"NK3\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the scf.in file and pseudopotentials in the current directory. 
#please prepare $FNAME.pw2wan.in and $FNAME.win in the current directory.
FNAME="$1"
NK1="$2"
NK2="$3"
NK3="$4"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x"
PW2W_COMMAND="$PARA_PREFIX pw2wannier90.x"
W90_COMMAND="$PARA_PREFIX wannier90.x"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "pw2w command: $PW2W_COMMAND"
echo "w90 command: $W90_COMMAND"
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
for INPUT in "${FNAME}.scf.in" "$FNAME.pw2wan.in" "$FNAME.win"
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

#generate nscf.w.in
NBND=$(awk '/Starting wfcs/ {print $4}' ${FNAME}.scf.out)
#NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
if [ "$NBND" = "random" ]; then
	NBND=$(awk '/number of Kohn-Sham states/ {print $5}' ${FNAME}.scf.out)
fi
TARGETLINE=$(($(sed -n '/\&system/=' ${FNAME}.scf.in)))
#sed -e "${TARGETLINE}a nbnd = $NBND" ${FNAME}.scf.in | sed -e "${TARGETLINE}a nosym = .true." | sed "s/calculation.*/calculation = \'nscf\'/" > ${FNAME}.nscf.w.in
sed -e "${TARGETLINE}a nbnd = $NBND" ${FNAME}.scf.in | sed "s/calculation.*/calculation = \'nscf\'/" > ${FNAME}.nscf.w.in
TARGETLINE=$(($(sed -n '/K_POINTS/=' ${FNAME}.nscf.w.in)))
sed -e "${TARGETLINE},$((TARGETLINE+1))d" -e '/occupations.*/d' -e '/smearing.*/d' -e '/degauss.*/d' ${FNAME}.nscf.w.in > ${FNAME}.tmp.in
kmesh.pl $NK1 $NK2 $NK3 >> ${FNAME}.tmp.in
mv ${FNAME}.tmp.in ${FNAME}.nscf.w.in
echo "diff ${FNAME}.scf.in ${FNAME}.nscf.w.in:"
diff ${FNAME}.scf.in ${FNAME}.nscf.w.in
echo
#verify that nscf.w.in is generated as expected

#nscf calc.
echo "nscf calc. start"
$PW_COMMAND < ${FNAME}.nscf.w.in > ${FNAME}.nscf.w.out
echo "nscf calc. finished"
echo

#preprocess for wannierization
echo "preprocess start"
$W90_COMMAND -pp ${FNAME}
$PW2W_COMMAND < ${FNAME}.pw2wan.in > ${FNAME}.pw2wan.out
echo "preprocess finished"
echo

#wannierization
echo "wannierization start"
$W90_COMMAND ${FNAME}
echo "wannierization finished"
echo
