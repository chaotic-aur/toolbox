#!/bin/bash
#SBATCH --job-name=hourly.1
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --exclusive
#SBATCH --dependency=singleton
#SBATCH --time=00:50:00
#SBATCH --signal=B:SIGUSR1@90

# shellcheck disable=SC2034
JOB_PERIOD=3600
# shellcheck disable=SC2034
JOB_OFFSET=0

# shellcheck source=/dev/null
source common.sh
