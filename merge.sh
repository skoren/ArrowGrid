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

source ~/.profile

if [ -e `pwd`/CONFIG ]; then
   CONFIG=`pwd`/CONFIG
else
   CONFIG=${SCRIPT_PATH}/CONFIG
fi
LD_ADDITION=`cat $CONFIG |grep -v "#"  |grep LD_LIBRARY_PATH |wc -l`
if [ $LD_ADDITION -eq 1 ]; then
   LD_ADDITION=`cat $CONFIG |grep -v "#" |grep LD_LIBRARY_PATH |tail -n 1 |awk '{print $NF}'`
   export LD_LIBRARY_PATH=$LD_ADDITION:$LD_LIBRARY_PATH
fi

wrk=`pwd`
syst=`uname -s`
arch=`uname -m`
name=`uname -n`

if [ "$arch" = "x86_64" ] ; then
  arch="amd64"
fi

prefix=`cat prefix`
asm=`cat asm`
ALGORITHM=`cat alg`
NUM_JOBS=`wc -l input.fofn |awk '{print $1}'`

if [ ! -s $prefix.xml ]; then
   echo "Error: failure in previous step"
   exit 1
fi

echo "Cleaning up"
for f in `ls $prefix.[0-9]*aln.bam`; do
   jobnum=`basename $f |sed s/$prefix.//g |sed s/.aln.bam//g`
   IS_OK=`cat *$jobnum.cns.out |grep -c Finished`
   IS_OUT_OF_BOUNDS=`cat *$jobnum.cns.out |grep -c "invalid job id"`
   if [ $IS_OK -ge 1 ]; then
      echo "$jobnum is OK"
      rm -f $f
      rm -f $f.pbi
      rm -f $f.bai
   elif [ $IS_OUT_OF_BOUNDS -ge 1 ]; then
      echo "$jobnum is out of bounds, which is OK"
      rm -f $f
      rm -f $f.pbi
      rm -f $f.bai
   else
      echo "Error: $jobnum failed, please check $jobnum.cns.out for errors and try again"
      exit
   fi
done

if [ -e $prefix.$ALGORITHM.fastq ]; then
   echo "Already done"
else
   echo "Consensus completed, merging results"
   cat $prefix.[0-9]*.fasta > $prefix.$ALGORITHM.WORKING.fasta && mv $prefix.$ALGORITHM.WORKING.fasta $prefix.$ALGORITHM.fasta
   cat $prefix.[0-9]*.fastq > $prefix.$ALGORITHM.WORKING.fastq && mv $prefix.$ALGORITHM.WORKING.fastq $prefix.$ALGORITHM.fastq
   cat $prefix.[0-9]*.gff > $prefix.$ALGORITHM.WORKING.gff && mv $prefix.$ALGORITHM.WORKING.gff $prefix.$ALGORITHM.gff

   if [ -e $prefix.$ALGORITHM.gff ]; then
      rm -f $prefix.[0-9]*.gff
   fi
   if [ -e $prefix.$ALGORITHM.fasta ]; then
      rm -f $prefix.[0-9]*.fasta
   fi
   if [ -e $prefix.$ALGORITHM.fastq ]; then
      rm -f $prefix.[0-9]*.fastq
   fi
fi
