#!/bin/bash
#SBATCH --job-name=hourly.1
#SBATCH --mincpus 40
#SBATCH --exclusive
#SBATCH --mem 0
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --dependency=singleton
#SBATCH --time=02:20:00
#SBATCH --signal=B:SIGUSR1@90

# shellcheck disable=SC2034
JOB_PERIOD=3600
# shellcheck disable=SC2034
JOB_OFFSET=0

export CAUR_PARALLEL=10

# shellcheck source=/dev/null
source common.sh
