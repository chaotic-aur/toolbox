#!/bin/bash
#SBATCH --job-name=daily.1
#SBATCH --partition fast
#SBATCH --nodes 1
#SBATCH --cpus-per-task=20
#SBATCH --dependency=singleton
#SBATCH --time=01:00:00
#SBATCH --signal=B:SIGUSR1@90

JOB_PERIOD=$((24*3600))
JOB_OFFSET=$(( 1*3600))

source common.sh
