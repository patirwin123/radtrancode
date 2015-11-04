#!/bin/csh
# ---------------------------------------------------------------------
# Script to remake main Binaries (run after Make_all_lib.csh )
# ---------------------------------------------------------------------
# 4/11/15	NAT	Original Version
# ---------------------------------------------------------------------
#

cd radtran
  cd radtran
    foreach p ( Aground Calc_fnktablec Pl_spec Radtrans Read_table )
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      echo "-- $p "
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      make $p
    end
  cd ../
  cd path
    foreach p ( Convert_prf Profile Path )
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      echo "-- $p "
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      make $p
    end
  cd ../
  cd scatter
    foreach p ( Makephase )
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      echo "-- $p "
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      make $p
    end
  cd ../
  cd spec_data
    foreach p ( Select Makedb )
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      echo "-- $p "
      echo "---------------------------------------------"
      echo "---------------------------------------------"
      make $p
    end
  cd ../
cd ../

cd nemesis
  foreach p ( Nemesis )
    echo "---------------------------------------------"
    echo "---------------------------------------------"
    echo "-- $p "
    echo "---------------------------------------------"
    echo "---------------------------------------------"
    make $p
  end
cd ../