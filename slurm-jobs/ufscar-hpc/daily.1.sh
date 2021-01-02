#!/bin/bash
#SBATCH --job-name=daily.1
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --exclusive
#SBATCH --dependency=singleton
#SBATCH --time=02:00:00
#SBATCH --signal=B:SIGUSR1@90

JOB_PERIOD=$((24*3600))
JOB_OFFSET=$(( 4*3600))

source common.sh
