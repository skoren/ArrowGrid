#!/usr/bin/env bash

######################################################################
#  PUBLIC DOMAIN NOTICE
#
#  This software is "United States Government Work" under the terms of the United
#  States Copyright Act. It was written as part of the authors' official duties
#  for the United States Government and thus cannot be copyrighted. This software
#  is freely available to the public for use without a copyright
#  notice. Restrictions cannot be placed on its present or future use.
#
#  Although all reasonable efforts have been taken to ensure the accuracy and
#  reliability of the software and associated data, the National Human Genome
#  Research Institute (NHGRI), National Institutes of Health (NIH) and the
#  U.S. Government do not and cannot warrant the performance or results that may
#  be obtained by using this software or data. NHGRI, NIH and the U.S. Government
#  disclaim all warranties as to performance, merchantability or fitness for any
#  particular purpose.
#
#  Please cite the authors in any work or product based on this material.
######################################################################

SCRIPT_PATH=`cat scripts`

if [ -e `pwd`/CONFIG ]; then
   CONFIG=`pwd`/CONFIG
else
   CONFIG=${SCRIPT_PATH}/CONFIG
fi

LD_ADDITION=`cat $CONFIG |grep -v "#" |grep LD_LIBRARY_PATH |wc -l`
if [ $LD_ADDITION -eq 1 ]; then
   LD_ADDITION=`cat $CONFIG |grep -v "#" |grep LD_LIBRARY_PATH |tail -n 1 | awk '{print $NF}'`
   export LD_LIBRARY_PATH=$LD_ADDITION:$LD_LIBRARY_PATH
fi

wrk=`pwd`
syst=`uname -s`
arch=`uname -m`
name=`uname -n`

if [ "$arch" = "x86_64" ] ; then
  arch="amd64"
fi

GRID=`cat $CONFIG |grep -v "#" |grep  GRIDENGINE |tail -n 1 |awk '{print $2}'`

if [ $GRID == "SGE" ]; then
   baseid=$SGE_TASK_ID
   offset=$1
   cores=$NSLOTS
elif [ $GRID == "LSF" ]; then
   baseid=$LSB_JOBINDEX
   offset=$1
   #LSB_MCPU_HOSTS=blade18-1-2.gsc.wustl.edu 8
   cores=$(echo ${LSB_MCPU_HOSTS} | awk '{print $2}')
elif [ $GRID == "SLURM" ]; then
   baseid=$SLURM_ARRAY_TASK_ID
   offset=$1
   cores=$SLURM_CPUS_PER_TASK
fi

if [ x$baseid = x -o x$baseid = xundefined -o x$baseid = x0 ]; then
  baseid=$1
  offset=0
  cores=`grep -c ^processor /proc/cpuinfo`
fi

if [ x$offset = x ]; then
  offset=0
fi

jobid=`expr $baseid + $offset`

if test x$jobid = x; then
  echo Error: I need SGE_TASK_ID set, or a job index on the command line
  exit 1
fi

echo Running job $jobid based on command line options.

fofn=`cat fofn`
line=`cat $fofn |head -n $jobid |tail -n 1`
prefix=`cat prefix`
reference=`cat asm`

if [ -e $prefix.$jobid.aln.bam.pbi ]; then
   echo "Already done"
   exit
fi

IS_BAM=`echo $line |grep ".bam$" |wc -l |awk '{print $1}'`
if [ $IS_BAM -eq 0 ]; then
   # not a bam input convert
   echo "Not a bam input, assuming P6-C4 chemistry, converting to BAM"
   fofn=`echo $line |awk '{print $1}'`
   `find $fofn*.bax.h5 > $prefix.$jobid.fofn`
   bax2bam -f $prefix.$jobid.fofn -o $prefix.$jobid
   line="$prefix.$jobid.subreads.bam"
fi

echo "Mapping $prefix $line to $reference"
mkdir -p tmpdir
pbalign --tmpDir=`pwd`/tmpdir --minAccuracy=0.75 --minLength=50 --minAnchorSize=12 --maxDivergence=30 --concordant --algorithm=blasr --algorithmOptions=--useQuality --maxHits=1 --hitPolicy=random --seed=1 --nproc=$cores $line $reference $prefix.$jobid.aln.bam 
bamtools stats -in $prefix.$jobid.aln.bam

if [ $IS_BAM -eq 0 ]; then
   # removing converted bam file
   rm -f $line
fi
