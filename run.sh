#!/bin/bash
#SBATCH --job-name=mousecys
#SBATCH -o ./test-output-%j.txt
#SBATCH -e ./test-error-%j.txt
#SBATCH -D .
#SBATCH --ntasks=4

MOL=$1

###AMBER


module load python/3.8.8 intel/2022.3 mkl/2022.2.0 impi/2021.7.0 amber/22/intel/2022.3/impi/2021.7

export PMEMD="srun --mpi=pmi2 pmemd.MPI"


#1.- Minimization steps
#The system was energetically minimized in three steps where the entire system is gradually relaxed

$PMEMD -O -i min1.in -o $1.min1.out -p $1.prmtop -c $1.inpcrd -r $1.m1.rst -ref $1.inpcrd
$PMEMD -O -i min2.in -o $1.min2.out -p $1.prmtop -c $1.m1.rst -r $1.m2.rst -ref $1.inpcrd
$PMEMD -O -i min3.in -o $1.min3.out -p $1.prmtop -c $1.m2.rst -r $1.m3.rst -ref $1.inpcrd

#2.- Heating (100 --> 300K)
#the system is heated up using the Langevin thermostat from 100 to 300 K of linear increase in the temperature in a NVT ensemble.

$PMEMD -O -i h.in -o $1.h.out -p $1.prmtop -c $1.m3.rst -r $1.h.rst -x $1.h.nc -ref $1.m3.rst

#3.- Equilibration steps (=pre-production)
#the first four steps of equilibration are in the NVT ensemble, fith and sixth under NPT ensemble, restrains are removed in sixth step.
#restraint is an energetic bias that tends to force the calculation toward a certain restriction.

$PMEMD -O -i eq1.in -o $1.eq1.out -p $1.prmtop -c $1.h.rst -r $1.eq1.rst -x $1.eq1.nc -ref $1.h.rst
$PMEMD -O -i eq2.in -o $1.eq2.out -p $1.prmtop -c $1.eq1.rst -r $1.eq2.rst -x $1.eq2.nc -ref $1.eq1.rst
$PMEMD -O -i eq3.in -o $1.eq3.out -p $1.prmtop -c $1.eq2.rst -r $1.eq3.rst -x $1.eq3.nc -ref $1.eq2.rst
$PMEMD -O -i eq4.in -o $1.eq4.out -p $1.prmtop -c $1.eq3.rst -r $1.eq4.rst -x $1.eq4.nc -ref $1.eq3.rst
$PMEMD -O -i eq5.in -o $1.eq5.out -p $1.prmtop -c $1.eq4.rst -r $1.eq5.rst -x $1.eq5.nc -ref $1.eq4.rst
$PMEMD -O -i eq6.in -o $1.eq6.out -p $1.prmtop -c $1.eq5.rst -r $1.eq6.rst -x $1.eq6.nc -ref $1.eq5.rst

rm -f $1.md0.rst
ln -s $1.eq6.rst $1.md0.rst

#4.- MD production
for i in `seq 1 1 400`; do
echo $i
j=$((i-1))
$PMEMD -O -i md.in -o $1.md$i.out -p $1.prmtop -c $1.md$j.rst -r $1.md$i.rst -x $1.md$i.nc -ref $1.md$j.rst
bzip2 $1.md$j.rst $1.md$j.nc
done
##
