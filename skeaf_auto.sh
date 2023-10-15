#!/bin/bash

#prepare 'config_bandXX.in' and '*.bxsf' for each band in current directory.
#then, correctly set the following scripts, e.g., corename and band index.
#results are stored in the directries $corename/bandXX.

corename="btoc"

mkdir $corename
mkdir $corename/band10
mkdir $corename/band11
#mkdir $corename/bandXX
#mkdir $corename/bandXX

cp config_band10.in config.in
skeaf -rdcfg
mv *.out $corename/band10

cp config_band11.in config.in
skeaf -rdcfg
mv *.out $corename/band11

#cp config_bandXX.in config.in
#skeaf -rdcfg
#mv *.out $corename/bandXX

#cp config_bandXX.in config.in
#skeaf -rdcfg
#mv *.out $corename/bandXX

