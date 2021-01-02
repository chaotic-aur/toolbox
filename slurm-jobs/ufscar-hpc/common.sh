function _requeue() {
  local now timespec
  now="$(date '+%s')"
  timespec="$(date --date="@$(((now/JOB_PERIOD+1)*JOB_PERIOD+JOB_OFFSET))" '+%Y-%m-%dT%H:%M:%S')"

  echo "$(date): requeing job $SLURM_JOBID ($SLURM_JOB_NAME) to run at $timespec"

  scontrol requeue "$SLURM_JOBID"
  scontrol update JobId="$SLURM_JOBID" StartTime="$timespec"

  trap - EXIT  # avoid double-requeuing
}

function _near_timeout() {
  _requeue
  if [[ -n "$CHILD_PID" ]]; then
    echo "$(date): notifying child $CHILD_PID about timeout"
    kill -SIGUSR1 "$CHILD_PID"
  fi
}

function sane-wait() {
  # https://stackoverflow.com/a/35755784/13649511
  local status=0
  while :; do
    wait "$@" || local status="$?"
    if [[ "$status" -lt 128 ]]; then
      return "$status"
    fi
  done
}

trap '_near_timeout' SIGUSR1  # job needs to specify --signal=B:SIGUSR1@90
trap '_requeue' EXIT  # handle requeue on normal conditions (no timeout)

echo "$(date): job $SLURM_JOBID ($SLURM_JOB_NAME) starting on $SLURM_NODELIST"

chaotic routine "$SLURM_JOB_NAME" &
CHILD_PID="$!"

echo "$(date): child running with pid $CHILD_PID"
sane-wait "$CHILD_PID"
