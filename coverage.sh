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
. "${CONFIG}"

if [ ! -z "${LD_ADDITION}" ]; then
   export LD_LIBRARY_PATH=$LD_ADDITION:$LD_LIBRARY_PATH
fi

wrk=`pwd`
syst=`uname -s`
arch=`uname -m`
name=`uname -n`

if [ "$arch" = "x86_64" ] ; then
  arch="amd64"
fi

if [ $GRID == "SGE" ]; then
   baseid=$SGE_TASK_ID
   offset=$1
elif [ $GRID == "LSF" ]; then
   baseid=$LSB_JOBINDEX
   offset=$1
   #LSB_MCPU_HOSTS=blade18-1-2.gsc.wustl.edu 8
   cores=$(echo ${LSB_MCPU_HOSTS} | awk '{print $2}')
elif [ $GRID == "SLURM" ]; then
   baseid=$SLURM_ARRAY_TASK_ID
   offset=$1
fi

if [ x$baseid = x -o x$baseid = xundefined -o x$baseid = x0 ]; then
  baseid=$1
  offset=0
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

prefix=`cat prefix`
asm=`cat asm`
chunk=`echo $jobid |awk '{print $1-1}'`
if [ ! -e $prefix.chunk$chunk.xml ]; then
   echo "Error: invalid job id $jobid, cannot find $prefix.chunk$chunk.xml"
   exit
fi
chunk="$prefix.chunk$chunk.xml"
echo "Running with $prefix $asm on $chunk"

if [ -e "$prefix.$jobid.coverage" ]; then
   echo "Already done!"
   exit
fi

# instantiate/consolidate the dataset (this is IO penalty) and then dump coverage
dataset consolidate $chunk $prefix.$jobid.byCtg.aln.bam $prefix.$jobid.byCtg.xml
bamtools coverage -in $prefix.$jobid.byCtg.aln.bam -out $prefix.$jobid.coverage
