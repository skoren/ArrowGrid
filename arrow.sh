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

MACHINE=`uname`
PROC=`uname -p`
SCRIPT_PATH=$BASH_SOURCE
SCRIPT_PATH=`dirname $SCRIPT_PATH`
JAVA_PATH=$SCRIPT_PATH:.

FOFN=$1
PREFIX=$2
REFERENCE=$3

NUM_JOBS=`wc -l $FOFN |awk '{print $1}'`

ALGORITHM=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#" |grep  ALGORITHM |tail -n 1 |awk '{print $2}'`
echo "$FOFN" > fofn
echo "$PREFIX" > prefix
echo "$REFERENCE" > asm
echo "$SCRIPT_PATH" > scripts
echo "$ALGORITHM" > alg

echo "Running with $PREFIX $REFERENCE $HOLD_ID"
USEGRID=`cat ${SCRIPT_PATH}/CONFIG |grep -v "#" |grep USEGRID |awk '{print $NF}'`
if [ $USEGRID -eq 1 ]; then
   if [ $# -ge 4 ] && [ x$4 != "x" ]; then
       qsub -V -pe thread 8 -tc 50 -l mem_free=5G -t 1-$NUM_JOBS -hold_jid $5 -cwd -N "${PREFIX}align" -j y -o `pwd`/\$TASK_ID.out $SCRIPT_PATH/filterAndAlign.sh
   else
       qsub -V -pe thread 8 -tc 50 -l mem_free=5G -t 1-$NUM_JOBS  -cwd -N "${PREFIX}align" -j y -o `pwd`/\$TASK_ID.out $SCRIPT_PATH/filterAndAlign.sh
   fi
   qsub -V -pe thread 1 -l mem_free=5G -hold_jid "${PREFIX}align" -cwd -N "${PREFIX}split" -j y -o `pwd`/split.out $SCRIPT_PATH/splitByContig.sh
   qsub -V -pe thread 8 -l mem_free=5G -tc 50 -t 1-$NUM_JOBS -hold_jid "${PREFIX}split" -cwd -N "${PREFIX}cns" -j y -o `pwd`/\$TASK_ID.cns.out $SCRIPT_PATH/consensus.sh
   #qsub -V -pe thread 1 -l mem_free=5G -tc 400 -hold_jid "${PREFIX}split" -t 1-$NUM_JOBS -cwd -N "${PREFIX}cov" -j y -o `pwd`/\$TASK_ID.cov.out $SCRIPT_PATH/coverage.sh
   qsub -V -pe thread 1 -l mem_free=5G -hold_jid "${PREFIX}cns" -cwd -N "${PREFIX}merge" -j y -o `pwd`/merge.out $SCRIPT_PATH/merge.sh
else
   echo "Generating alignments"
   for i in `seq 1 $NUM_JOBS`; do
      sh $SCRIPT_PATH/filterAndAlign.sh $i
   done
   echo "Splitting by contig"
   sh $SCRIPT_PATH/splitByContig.sh
   echo "Computing consensus"
   for i in `seq 1 $NUM_JOBS`; do
      sh $SCRIPT_PATH/consensus.sh $i
   done
   echo "Computing coverage stats"
   #for i in `seq 1 $NUM_JOBS`; do
   #   sh $SCRIPT_PATH/coverage.sh $i
   #done
   sh $SCRIPT_PATH/merge.sh
fi
