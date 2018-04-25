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
NUM_JOBS=`wc -l input.fofn |awk '{print $1}'`
NUM_CTG=`grep -c ">" $asm`
if [ $NUM_CTG -lt $NUM_JOBS ]; then
   NUM_JOBS=$NUM_CTG
fi

# check for failures in mapping
for f in `ls $prefix.[0-9]*.aln.bam`; do
   if [ ! -s $f ]; then
       echo "Error: file $f is empty, check output from mapping step"
       exit 1
   fi
done

echo "Cleaning up"
rm -f $prefix.filtered.$jobid*
rm -rf tmpdir
rm -rf filtered

if [ -e $prefix.xml ]; then
   echo "Already done"
else
   echo "Splitting $asm into $NUM_CTG $NUM_JOBS"
   samtools faidx $asm
   dataset create --type AlignmentSet $prefix.xml $prefix.[0-9]*.aln.bam
   dataset split --contig --maxChunks $NUM_JOBS --chunks $NUM_JOBS --outdir `pwd` $prefix.xml
fi
