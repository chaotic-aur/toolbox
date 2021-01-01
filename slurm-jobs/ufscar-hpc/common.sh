_requeue() {
  local now timespec
  now="$(date '+%s')"
  timespec="$(date --date="@$(((now/JOB_PERIOD+1)*JOB_PERIOD+JOB_OFFSET))" '+%Y-%m-%dT%H:%M:%S')"

  echo "$(date): requeing job $SLURM_JOBID ($SLURM_JOB_NAME) to run at $timespec"

  scontrol requeue "$SLURM_JOBID"
  scontrol update JobId="$SLURM_JOBID" StartTime="$timespec"
}
trap '_requeue' SIGUSR1 EXIT HUP INT QUIT TERM ERR

echo "$(date): job $SLURM_JOBID ($SLURM_JOB_NAME) starting on $SLURM_NODELIST"

chaotic routine "$SLURM_JOB_NAME"
