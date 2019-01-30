# ArrowGrid

The distribution is a parallel wrapper around the [Arrow](http://github.com/PacificBiosciences/GenomicConsensus/) consensus framework within the [SMRT Analysis Software](http://github.com/PacificBiosciences/SMRT-Analysis). The pipeline is composed of bash scripts, an example input fofn which shows how to input your bax.h5 files (you give paths without the .1.bax.h5), and how to launch the pipeline. The input can be either BAX.h5 or BAM files (only P6-C4 chemistry or newer) and requires SMRTportal 3.1+. It can also run the older Quiver algorithm if requested in the CONFIG file on the P6-C4 chemistry data.

The current pipeline has been designed to run on the SGE or SLURM scheduling systems and has hard-coded grid resource request parameters. You must edit arrow.sh to match your grid options. It is, in principle, possible to run on other grid engines but will require editing all shell scripts to not use SGE_TASK_ID but the appropriate variable for your grid environment and editing the qsub commands in arrow.sh to the appropriate commands for your grid environment.

To run the pipeline you need to:

1. You must have a working SMRT Analysis Software installation and have it configured so the tools are in your path.

2. Create the input.fofn file which lists the SMRTcells you want to use for Arrow. For h5 files, specify the full path (excluding .[1-3].bax.h5) which are all treated as a single SMRTcell. For BAM files, specify the full path (including subreads.bam).

3. run the pipeline specifying the input file, a prefix for the outputs, and the path to the reference fasta. Optionally you can also specify a path to a Canu seqStore readNames.txt file if you used trio binning and want to only use classified reads for polishing.

```
sh arrow.sh input.fofn trio3 trio3.contigs.fasta
```

The pipeline is very rough and has undergone limited testing so user beware.

### CITE
If you find this pipeline useful, please cite the original Quiver paper:<br>
Chin et al. [Nonhybrid, finished microbial genome assemblies from long-read SMRT sequencing data.](http://www.nature.com/nmeth/journal/v10/n6/full/nmeth.2474.html) Nature Methods, 2013

and the Canu paper:<br>
Koren S et al. [Canu: scalable and accurate long-read assembly via adaptive k-mer weighting and repeat separation](https://doi.org/10.1101/gr.215087.116). Genome Research. (2017).
