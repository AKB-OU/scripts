#!/bin/bash

corename="ctoa"

mkdir $corename
mkdir $corename/band17
mkdir $corename/band19
mkdir $corename/band21
mkdir $corename/band23

cp config_band17.in config.in
skeaf -rdcfg
mv *.out $corename/band17

cp config_band19.in config.in
skeaf -rdcfg
mv *.out $corename/band19

cp config_band21.in config.in
skeaf -rdcfg
mv *.out $corename/band21

cp config_band23.in config.in
skeaf -rdcfg
mv *.out $corename/band23
