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

prefix=`cat prefix`
asm=`cat asm`
ploidy="haploid"
ALGORITHM=`cat alg`
DIPLOID=""
if [ $ploidy == "haploid" ]; then
   DIPLOID=""
elif [ $ploidy == "diploid" ]; then
   DIPLOID="" # --diploid "
else
   echo "Invalid ploidy $ploidy"
   exit 1
fi

chunk=`echo $jobid |awk '{print $1-1}'`
if [ ! -e $prefix.chunk$chunk.xml ]; then
   echo "Error: invalid job id $jobid, cannot find $prefix.chunk$chunk.xml"
   exit
fi
chunk="$prefix.chunk$chunk.xml"
echo "Running with $prefix $asm on $chunk"
echo "$ALGORITHM $SCRIPT_PATH $DIPLOID"

if [ -s "$prefix.$jobid.fasta" ]; then
   echo "Already done!"
   exit
else
   # not complete, remove any outputs (if they exist)
   rm -f $prefix.$jobid.fasta
   rm -f $prefix.$jobid.fastq
   rm -f $prefix.$jobid.gff
fi

# do we want to instantiate partitioned bam here or not?
variantCaller --skipUnrecognizedContigs $DIPLOID -x 5 -q 20 -X120 -v -j $cores --algorithm=$ALGORITHM -r $asm -o $prefix.$jobid.gff -o $prefix.$jobid.fastq -o $prefix.$jobid.fasta $chunk
