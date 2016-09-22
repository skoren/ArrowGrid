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
unset PYTHONPATH

LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#"  |grep LD_LIBRARY_PATH |wc -l`
if [ $LD_ADDITION -eq 1 ]; then
   LD_ADDITION=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#"  |grep LD_LIBRARY_PATH |tail -n 1 |awk '{print $NF}'`
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

if test x$jobid = x; then
  echo Error: I need SGE_TASK_ID set, or a job index on the command line
  exit 1
fi

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

if [ -e "$prefix.$jobid.fasta" ]; then
   echo "Already done!"
   exit
fi

# do we want to instantiate partitioned bam here or not?
variantCaller.py --skipUnrecognizedContigs $DIPLOID -x 5 -q 20 -X120 -v -j8 --algorithm=$ALGORITHM -r $asm -o $prefix.$jobid.gff -o $prefix.$jobid.fastq -o $prefix.$jobid.fasta $chunk
