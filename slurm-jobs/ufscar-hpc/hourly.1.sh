#!/bin/bash
#SBATCH --job-name=hourly.1
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --dependency=singleton
#SBATCH --time=00:30:00
#SBATCH --signal=B:SIGUSR1@90

JOB_PERIOD=3600
JOB_OFFSET=0

source "$(dirname "$0")"/common.sh
