#!/bin/bash
set -o nounset

# Apply manifests of SNO clusters that will be installed via Assisted Installer.
# Please create the manifests first via script create-manifests.sh.
# Usage:
#   ./apply-manifests.sh [NUM_CONCURRENT_APPLY] [INTERVAL_SECOND]
# By default, maximum 1000 clusters will be applied at the same time, with no break in between each apply.

num_concurrent_apply=${1:-'100'}
interval_second=${2:-'15'}

export KUBECONFIG=/root/bm/kubeconfig

STOP_LOOP=false
function ctrl_c() {
    STOP_LOOP=true
    echo "Trapped CTRL-C: terminate all child process"
    for pid in ${pids[*]}; do
        kill -9 $pid
    done
}
# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function timestampLog() {
	d=$(date +"%Y-%m-%dT%H:%M:%SZ")
	echo "$(python3 -c 'import time;print(int(time.time() * 1000))'), $d,"$@""
}

function retry {
    local n=0
    local max=5
    local delay=15

    n=0
    until [ "$n" -ge $max ]; do
        "$@"
        if [ "$?" -eq 0 ]; then
            break
        fi
        ((n++))
        sleep $delay
        timestampLog "Command failed. Attempt $n/$max:" | tee -a "$log_file"
    done
}

i=1 # Start with 1 because zsh arrays starting index is 1 instead of 0
for cluster_dir in clusters/*; do
    [ "$STOP_LOOP" = "true" ] && break;

    # If i is divisible by num_concurrent_apply
    if ! ((i % num_concurrent_apply)); then
        timestampLog "----sleeping for $interval_second seconds" | tee -a "$log_file"
        sleep "$interval_second"
    fi

    log_file="$cluster_dir"/logs
    true > "$log_file"
    timestampLog "Applying manifests for $cluster_dir" | tee -a "$log_file"
    retry oc apply -f "$cluster_dir"/manifest &>> "$log_file" &
    ((i++))
    pids[${i}]=$!
done

for pid in ${pids[*]}; do
    wait $pid
done