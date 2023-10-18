#!/bin/bash

#modified 2023.1.23

if [ $# -ne 4 ]; then
    echo "ERROR in number of parameters"
    echo "usage: routine_epw.sh \"FNAME\" \"NK1\" \"NK2\" \"NK3\""
    exit 1
fi

#we assume that input file name is "$FNAME.scf.in"
#please prepare the scf.in and epw.in. 
FNAME="$1"
NK1="$2"
NK2="$3"
NK3="$4"

CURRENT_DIR=$(pwd)
P_CPU=$( fgrep 'physical id' /proc/cpuinfo | sort -u | wc -l )
CORES=$( fgrep 'cpu cores' /proc/cpuinfo | sort -u | sed 's/.*: //' )
PARA_PREFIX="mpirun -np $((P_CPU*CORES))"
SUFFIX="-npool $((P_CPU*CORES))"
PW_COMMAND="$PARA_PREFIX pw.x $SUFFIX"
EPW_COMMAND="$PARA_PREFIX epw.x $SUFFIX"

echo "current directory: $CURRENT_DIR"
echo "pw command: $PW_COMMAND"
echo "epw command: $EPW_COMMAND"
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
for INPUT in "${FNAME}.scf.in" "epw.in"
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

#we perform calculations with order of epw.in => epw.in2 => epw.in4 => epw.in3 => eliashberg.in
#we make all inputs first

#-------------------------------------------------------------------
#make inputs
#-------------------------------------------------------------------

#generate epw.in2
sed -e "s/epbwrite.*/epbwrite = .false./" -e "s/epbread.*/epbread = .false./" -e "s/epwwrite.*/epwwrite = .false./" -e "s/epwread.*/epwread = .true./" -e "s/wannierize.*/wannierize = .false./" -e "s/band_plot.*/band_plot = .true./" -e '/nkf1.*/d' -e '/nkf2.*/d' -e '/nkf3.*/d' -e '/nqf1.*/d' -e '/nqf2.*/d' -e '/nqf3.*/d' epw.in > epw.in2_tmp

TARGETLINE=$(($(sed -n '/\&inputepw/=' epw.in2_tmp)))
sed -e "${TARGETLINE}a filqf = '${FNAME}_cband.kpt'" epw.in2_tmp | sed -e "${TARGETLINE}a filkf = '${FNAME}_cband.kpt'" > epw.in2

rm epw.in2_tmp

echo "diff epw.in epw.in2:"
diff epw.in epw.in2
echo
#verify that epw.in2 is generated as expected

#generate epw.in3
sed -e "s/phonselfen.*/phonselfen = .true./" -e "s/a2f.*/a2f = .false./" -e "s/band_plot.*/band_plot = .false./" -e "s/delta_approx.*/delta_approx = .true./" -e "s/nest_fn.*/nest_fn = .true./" -e '/filkf.*/d' -e '/filkf.*/d' epw.in2 > epw.in3_tmp

TARGETLINE=$(($(sed -n '/\&inputepw/=' epw.in3_tmp)))
sed -e "${TARGETLINE}a fsthick = 0.2 ! eV" epw.in3_tmp | sed -e "${TARGETLINE}a rand_k = .true." | sed -e "${TARGETLINE}a rand_nk = 15625" > epw.in3

rm epw.in3_tmp

echo "diff epw.in2 epw.in3:"
diff epw.in2 epw.in3
echo
#verify that epw.in3 is generated as expected

#generate epw.in4
sed -e "s/a2f.*/a2f = .true./" -e '/filqf.*/d' epw.in3 > epw.in4_tmp

TARGETLINE=$(($(sed -n '/\&inputepw/=' epw.in4_tmp)))
sed -e "${TARGETLINE}a rand_q = .true." epw.in4_tmp | sed -e "${TARGETLINE}a rand_nq = 15625" > epw.in4

rm epw.in4_tmp

echo "diff epw.in3 epw.in4:"
diff epw.in3 epw.in4
echo
#verify that epw.in4 is generated as expected

#generate eliashberg.in
sed -e "s/epbwrite.*/epbwrite = .false./" -e "s/epbread.*/epbread = .false./" -e "s/epwwrite.*/epwwrite = .false./" -e "s/epwread.*/epwread = .true./" -e "s/iverbosity.*/iverbosity = 2/" -e "s/max_memlt.*/max_memlt = 8/" -e "s/wannierize.*/wannierize = .false./" -e '/elecselfen.*/d' -e '/phonselfen.*/d' -e '/temps.*/d' -e '/a2f.*/d' -e '/nkf1.*/d' -e '/nkf2.*/d' -e '/nkf3.*/d' -e '/nqf1.*/d' -e '/nqf2.*/d' -e '/nqf3.*/d' epw.in > eliashberg.in_tmp

TARGETLINE=$(($(sed -n '/\&inputepw/=' eliashberg.in_tmp)))
sed -e "${TARGETLINE}a ephwrite = .true. ! Writes .ephmat files used when Eliasberg = .true." eliashberg.in_tmp | sed -e "${TARGETLINE}a fsthick = 0.2 ! eV" | sed -e "${TARGETLINE}a eliashberg  = .true." | sed -e "${TARGETLINE}a muc = 0.1" | sed -e "${TARGETLINE}a mp_mesh_k = .true." | sed -e "${TARGETLINE}a nkf3 = 75" | sed -e "${TARGETLINE}a nkf2 = 75" | sed -e "${TARGETLINE}a nkf1 = 75" | sed -e "${TARGETLINE}a nqf3 = 15" | sed -e "${TARGETLINE}a nqf2 = 15" | sed -e "${TARGETLINE}a nqf1 = 15" > eliashberg.in

rm eliashberg.in_tmp

echo "diff epw.in eliashberg.in:"
diff epw.in eliashberg.in
echo
#verify that eliashberg.in is generated as expected

#-------------------------------------------------------------------
#serial EPW calculations
#-------------------------------------------------------------------

#EPW_epmat_calc.
echo "EPW_epmat_calc start"
$EPW_COMMAND < epw.in > epw.out
#mpirun -np $((P_CPU*CORES)) epw.x -npool $((P_CPU*CORES)) < epw.in > epw.out
echo "EPW_epmat_calc finished"
echo

#generate kpt file (we assume ${FNAME}_band.kpt has been already generated in the 1st step with a WANNIER90 keyword "bands_plot = .true.")
#this should be put after the calculation of epw.in
sed -e "1s/$/ crystal/g" ${FNAME}_band.kpt > ${FNAME}_cband.kpt
echo "diff ${FNAME}_band.kpt ${FNAME}_cband.kpt:"
diff ${FNAME}_band.kpt ${FNAME}_cband.kpt
echo

#EPW_band_calc.
echo "EPW_band_calc start"
$EPW_COMMAND < epw.in2 > epw.out2
#mpirun -np $((P_CPU*CORES)) epw.x -npool $((P_CPU*CORES)) < epw.in2 > epw.out2
echo "EPW_band_calc finished"
echo

#EPW_a2f_calc.
echo "EPW_a2f_calc start"
$EPW_COMMAND < epw.in4 > epw.out4
#mpirun -np $((P_CPU*CORES)) epw.x -npool $((P_CPU*CORES)) < epw.in4 > epw.out4
echo "EPW_a2f_calc finished"
echo

#EPW_linewidth_calc.
echo "EPW_linewidth_calc start"
$EPW_COMMAND < epw.in3 > epw.out3
#mpirun -np $((P_CPU*CORES)) epw.x -npool $((P_CPU*CORES)) < epw.in3 > epw.out3
echo "EPW_linewidth_calc finished"
echo

#EPW_eliashberg_calc.
echo "EPW_eliashberg_calc start"
$EPW_COMMAND < eliashberg.in > eliashberg.out
#mpirun -np $((P_CPU*CORES)) epw.x -npool $((P_CPU*CORES)) < eliashberg.in > eliashberg.out
echo "EPW_eliashberg_calc finished"
echo

#Here is a template of epw.in.
#--
#&inputepw
#  prefix      = 'ZrB12',
#  outdir      = './work/'

#  elph        = .true.
#  epbwrite    = .true.
#  epbread     = .false.

#  epwwrite    = .true.
#  epwread     = .false.
  
#  lifc	      =	 .true.
#  asr_typ     = 'crystal'
#  ! ifc.q2r is needed in save/
  
#  etf_mem = 1 
#  max_memlt = 8

#  nbndsub     =  41
#  bands_skipped = 'exclude_bands = 1:4'

#  wannierize  = .true.
#  num_iter = 2000
#  dis_froz_max = 15
#  dis_froz_min = 5
#  proj(1)     = 'B: p'
#  proj(2)     = 'Zr: d'
#  wdata(1) = 'dis_num_iter = 40000'
#  wdata(2) = 'bands_plot = .true.'
#  wdata(3) = 'begin kpoint_path'
#  wdata(4) = 'G       0.000  0.000  0.000     K       0.375  0.375  0.750'
#  wdata(5) = 'U       0.625  0.625  0.250     X       0.500  0.500  0.000'
#  wdata(6) = 'X       0.500  0.500  0.000     W       0.750  0.500  0.250'
#  wdata(7) = 'W       0.500  0.250  0.750     L       0.500  0.500  0.500'
#  wdata(8) = 'L       0.500  0.500  0.500     G       0.000  0.000  0.000'
#  wdata(9) = 'G       0.000  0.000  0.000     X       0.500  0.000  0.500'
#  wdata(10) = 'end kpoint_path'
#  wdata(11) = 'bands_plot_format = gnuplot'
#  wdata(12) = 'fermi_surface_plot = .true.'
#  wdata(13) = 'fermi_energy = 11.6777'
#  wdata(14) = 'guiding_centres = .true.'
  
#  use_ws = .false.
  
#  band_plot = .false.
  
#  iverbosity  = 0
  
#  efermi_read = .false.
#  fermi_energy = 11.6777

#  elecselfen  = .false. 
#  phonselfen  = .false.

#  temps       = 0.05 ! K
#  degaussw    = 0.025 ! eV
#  degaussq = 0.05 ! meV

#  a2f         = .false.
#  delta_approx = .false.
#  nest_fn = .false.

#  dvscf_dir   = '../ZrB12_ph/work/save/'

#  nkf1         = 9
#  nkf2         = 9
#  nkf3         = 9

#  nqf1         = 3
#  nqf2         = 3
#  nqf3         = 3

#  nk1         = 9
#  nk2         = 9
#  nk3         = 9

#  nq1         = 3
#  nq2         = 3
#  nq3         = 3
# /
