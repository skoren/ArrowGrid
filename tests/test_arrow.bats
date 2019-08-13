#!/usr/bin/env bats

@test "copy-and-sed" {

  export TESTDIR="${BATS_TMPDIR}/bats"
  run mkdir -p "${TESTDIR}"
  [ "${status}" -eq 0 ]

  export ARROW="${TESTDIR}/arrow.sh"
  run cp -f arrow.sh "${TESTDIR}"
  [ "${status}" -eq 0 ]
  chmod 755 "${ARROW}"
  [ "${status}" -eq 0 ]

  run sed -i 's/bsub /echo bsub /' "${ARROW}"
  [ "${status}" -eq 0 ]

}

@test "run with LSF" {

  run "${BATS_TMPDIR}/bats/arrow.sh" input.fofn TEST REF
  [ "${status}" -eq 0 ]

  [ "${lines[0]}" == "Running with TEST REF " ]
  [ "${lines[1]}" == "bsub -M 32000000 -R 'rusage[mem=32000]' -n 8 -J TESTalign[1-139] -oo %I.out -q research-hpc -a 'docker(halllab/arrow-grid:latest)' /tmp/bats/filterAndAlign.sh" ]
  [ "${lines[2]}" == "bsub -M 8000000 -R 'rusage[mem=8000]' -n 1 -J TESTsplit -w done(TESTalign) -oo split.out -q research-hpc -a 'docker(halllab/arrow-grid:latest)' /tmp/bats/splitByContig.sh" ]
  [ "${lines[3]}" == "bsub -M 32000000 -R 'rusage[mem=32000]' -n 8 -J TESTcns[1-139] -w done(TESTsplit) -oo %I.cns.out -q research-hpc -a 'docker(halllab/arrow-grid:latest)' /tmp/bats/consensus.sh" ]
  [ "${lines[4]}" == "bsub -M 8000000 -R 'rusage[mem=8000]' -n 1 -J TESTmerge -w done(TESTcns) -oo merge.out -q research-hpc -a 'docker(halllab/arrow-grid:latest)' /tmp/bats/merge.sh" ]
  [ -z "${lines[5]}" ]

}

@test "cleanup" {
  run /bin/rm -rf "${BATS_TMPDIR}/bats"
  run /bin/ls "${BATS_TMPDIR}/bats"
  [ "${status}" -eq 2 ]

}
