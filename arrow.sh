#!/usr/bin/env bash

#set -x

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

if [ -e `pwd`/CONFIG ]; then
   CONFIG=`pwd`/CONFIG
else
   CONFIG=${SCRIPT_PATH}/CONFIG
fi
. "${CONFIG}"

echo "$FOFN" > fofn
echo "$PREFIX" > prefix
echo "$REFERENCE" > asm
echo "$SCRIPT_PATH" > scripts
echo "$ALGORITHM" > alg
echo "Running with $PREFIX $REFERENCE $HOLD_ID"

if [ $# -ge 4 ] && [ x$4 != "x" ]; then
   echo "$4" > whitelist
   mv $FOFN filterfofn
   mkdir -p seq
   cat filterfofn |awk -v P=$PREFIX -v PWD=`pwd` '{print PWD"/seq/"P"."NR".filtered.bam"}' > $FOFN
fi

if [ ! -z "${GRID}" ]; then
   if [ $GRID == "SGE" ]; then
      hold=""
      if [ $# -ge 4 ] && [ x$4 != "x" ]; then
          qsub -V -pe thread 8 -tc 50 -l mem_free=1G -t 1-$NUM_JOBS -cwd -N "${PREFIX}subset" -j y -o `pwd`/\$TASK_ID.subset.out $SCRIPT_PATH/subset.sh
          hold=" -hold_jid ${PREFIX}subset "
      fi 
      qsub -V -pe thread 8 -tc 50 -l mem_free=5G -t 1-$NUM_JOBS $hold -cwd -N "${PREFIX}align" -j y -o `pwd`/\$TASK_ID.out $SCRIPT_PATH/filterAndAlign.sh
      qsub -V -pe thread 1 -l mem_free=5G -hold_jid "${PREFIX}align" -cwd -N "${PREFIX}split" -j y -o `pwd`/split.out $SCRIPT_PATH/splitByContig.sh
      qsub -V -pe thread 8 -l mem_free=5G -tc 50 -t 1-$NUM_JOBS -hold_jid "${PREFIX}split" -cwd -N "${PREFIX}cns" -j y -o `pwd`/\$TASK_ID.cns.out $SCRIPT_PATH/consensus.sh
      #qsub -V -pe thread 1 -l mem_free=5G -tc 400 -hold_jid "${PREFIX}split" -t 1-$NUM_JOBS -cwd -N "${PREFIX}cov" -j y -o `pwd`/\$TASK_ID.cov.out $SCRIPT_PATH/coverage.sh
      qsub -V -pe thread 1 -l mem_free=5G -hold_jid "${PREFIX}cns" -cwd -N "${PREFIX}merge" -j y -o `pwd`/merge.out $SCRIPT_PATH/merge.sh

   elif [ $GRID == "LSF" ]; then
      if [ $# -ge 4 ] && [ x$4 != "x" ]; then
          bsub ${GRIDOPTS_SUBSET} -J "${PREFIX}subset[1-${NUM_JOBS}]" -oo '%I.subset.out' ${GRIDOPTS} ${SCRIPT_PATH}/subset.sh
          bsub ${GRIDOPTS_ALN} -J "${PREFIX}align[1-${NUM_JOBS}]" -w "done(${PREFIX}subset[*])" -oo '%I.out' ${GRIDOPTS} "${SCRIPT_PATH}/filterAndAlign.sh"

      else
          bsub ${GRIDOPTS_ALN} -J "${PREFIX}align[1-${NUM_JOBS}]" -oo '%I.out' ${GRIDOPTS} "${SCRIPT_PATH}/filterAndAlign.sh"
      fi
      bsub ${GRIDOPTS_SPLT} -J "${PREFIX}split" -w "done(${PREFIX}align)" -oo split.out ${GRIDOPTS} "${SCRIPT_PATH}/splitByContig.sh"
      bsub ${GRIDOPTS_CON} -J "${PREFIX}cns[1-${NUM_JOBS}]" -w "done(${PREFIX}split)" -oo '%I.cns.out' ${GRIDOPTS} "${SCRIPT_PATH}/consensus.sh"
      bsub ${GRIDOPTS_MRG} -J "${PREFIX}merge" -w "done(${PREFIX}cns)" -oo merge.out ${GRIDOPTS} "${SCRIPT_PATH}/merge.sh"

   elif [ $GRID == "SLURM" ]; then
      # get batch limits
      maxarray=`scontrol show config | grep MaxArraySize |awk '{print $NF-1}'`

      # filter if needed
      job=""
      if [ $# -ge 4 ] && [ x$4 != "x" ]; then
         command="sbatch -J ${PREFIX}align -D `pwd` --cpus-per-task=8 --mem-per-cpu=1g -o `pwd`/%A_%a.out --time=72:00:00"
         > subset.submit.out
         for offset in `seq 0 $maxarray $NUM_JOBS`; do 
            e=$maxarray
            m=`expr $maxarray + $offset`
            if [ $m -gt $NUM_JOBS ]; then
               e=`expr $NUM_JOBS - $offset`
           fi
           $command -a 1-$e -o `pwd`/%A_%a.subset.out $SCRIPT_PATH/subset.sh $offset >> subset.submit.out 2>&1
         done
         job=`cat subset.submit.out |awk '{print "afterany:"$NF}' |tr '\n' ',' |awk '{print substr($0, 1, length($0)-1)}'`
         job=" --depend=$job "
         echo "Submitted filter array job $job"
      fi

      command="sbatch -J ${PREFIX}align -D `pwd` --cpus-per-task=8 --mem-per-cpu=5g -o `pwd`/%A_%a.out --time=72:00:00 $job"
      > filter.submit.out
      for offset in `seq 0 $maxarray $NUM_JOBS`; do 
         e=$maxarray
         m=`expr $maxarray + $offset`
         if [ $m -gt $NUM_JOBS ]; then
            e=`expr $NUM_JOBS - $offset`
        fi
        $command -a 1-$e -o `pwd`/%A_%a.out $SCRIPT_PATH/filterAndAlign.sh $offset >> filter.submit.out 2>&1
      done
      job=`cat filter.submit.out |awk '{print "afterany:"$NF}' |tr '\n' ',' |awk '{print substr($0, 1, length($0)-1)}'`
      echo "Submitted filter array job $job"
      sbatch -J ${PREFIX}split -D `pwd` --cpus-per-task=1 --mem-per-cpu=5g --depend=$job -o `pwd`/split.out $SCRIPT_PATH/splitByContig.sh > split.submit.out 2>&1
      job=`cat split.submit.out |awk '{print "afterany:"$NF}' |tr '\n' ',' |awk '{print substr($0, 1, length($0)-1)}'`
      echo "Submitted split job $job"

      > cns.submit.out
      for offset in `seq 0 $maxarray $NUM_JOBS`; do
          e=$maxarray
          m=`expr $maxarray + $offset`
          if [ $m -gt $NUM_JOBS ]; then
             e=`expr $NUM_JOBS - $offset`
         fi
         sbatch -J ${PREFIX}cns -D `pwd` --cpus-per-task=8 --mem-per-cpu=5g --depend=$job --time=72:00:00 -a 1-$e -o `pwd`/%A_%a.cns.out $SCRIPT_PATH/consensus.sh $offset >> cns.submit.out 2>&1
      done
      job=`cat cns.submit.out |awk '{print "afterany:"$NF}' |tr '\n' ',' |awk '{print substr($0, 1, length($0)-1)}'`
      echo "Submitted consensus array $Job"
      sbatch -J ${PREFIX}merge -D `pwd` --cpus-per-task=1 --mem-per-cpu=5g --depend=$job -o `pwd`/merge.out $SCRIPT_PATH/merge.sh > merge.submit.out 2>&1
      job=`cat merge.submit.out |awk '{print "afterany:"$NF}' |tr '\n' ',' |awk '{print substr($0, 1, length($0)-1)}'`
      echo "Submitted merge job $job"
   else
      echo "Error: unknown grid engine specified $GRID, currently supported are SGE, SLURM, or LSF"
      exit
   fi
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
