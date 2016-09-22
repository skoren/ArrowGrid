#!/usr/bin/env bash

######################################################################
#Copyright (C) 2015, Battelle National Biodefense Institute (BNBI);
#all rights reserved. Authored by: Sergey Koren
#
#This Software was prepared for the Department of Homeland Security
#(DHS) by the Battelle National Biodefense Institute, LLC (BNBI) as
#part of contract HSHQDC-07-C-00020 to manage and operate the National
#Biodefense Analysis and Countermeasures Center (NBACC), a Federally
#Funded Research and Development Center.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions are
#met:
#
#* Redistributions of source code must retain the above copyright
#  notice, this list of conditions and the following disclaimer.
#
#* Redistributions in binary form must reproduce the above copyright
#  notice, this list of conditions and the following disclaimer in the
#  documentation and/or other materials provided with the distribution.
#
#* Neither the name of the Battelle National Biodefense Institute nor
#  the names of its contributors may be used to endorse or promote
#  products derived from this software without specific prior written
#  permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
######################################################################

SCRIPT_PATH=`cat scripts`

source ~/.profile
unset PYTHONPATH
LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#" |grep LD_LIBRARY_PATH |wc -l`
if [ $LD_ADDITION -eq 1 ]; then
   LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#" |grep LD_LIBRARY_PATH |tail -n 1 | awk '{print $NF}'`
   export LD_LIBRARY_PATH=$LD_ADDITION:$LD_LIBRARY_PATH
fi

wrk=`pwd`
syst=`uname -s`
arch=`uname -m`
name=`uname -n`

if [ "$arch" = "x86_64" ] ; then
  arch="amd64"
fi

jobid=$SGE_TASK_ID
if [ x$jobid = x -o x$jobid = xundefined -o x$jobid = x0 ]; then
jobid=$1
fi

echo "The id is $1 and SGE $SGE_TASK_ID"
env

if test x$jobid = x; then
  echo Error: I need SGE_TASK_ID set, or a job index on the command line
  exit 1
fi

line=`cat input.fofn |head -n $jobid |tail -n 1`
prefix=`cat prefix`
reference=`cat asm`
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
if [ -e $prefix.$jobid.aln.bam ]; then
   echo "Already done"
   exit
fi

mkdir -p tmpdir
pbalign --tmpDir=`pwd`/tmpdir --minAccuracy=0.75 --minLength=50 --minAnchorSize=12 --maxDivergence=30 --concordant --algorithm=blasr --algorithmOptions=-useQuality --maxHits=1 --hitPolicy=random --seed=1 --nproc=8 $line $reference $prefix.$jobid.aln.bam 
bamtools stats -in $prefix.$jobid.aln.bam
