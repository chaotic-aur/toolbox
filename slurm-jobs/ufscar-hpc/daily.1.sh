#!/bin/bash
#SBATCH --job-name=daily.1
#SBATCH --cpus-per-task 40
#SBATCH --mem 257500M
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --dependency=singleton
#SBATCH --time=04:50:00
#SBATCH --signal=B:SIGUSR1@90

# shellcheck disable=SC2034
JOB_PERIOD=$((24 * 3600))
# shellcheck disable=SC2034
JOB_OFFSET=$((10 * 3600))

export CAUR_PARALLEL=2

# shellcheck source=/dev/null
source common.sh
