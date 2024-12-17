#!/usr/bin/env bash

# Configuration
IMAGE="frodlik/optimaserver:latest"
CPU_THRESHOLD_BUSY=20        # CPU usage % threshold to consider a container "busy"
CPU_THRESHOLD_IDLE=5         # CPU usage % threshold to consider a container "idle"
CHECK_INTERVAL=30            # Check every 30 seconds
CONSECUTIVE_THRESHOLD=2      # 2 consecutive checks for scaling decisions
CONTAINERS=("srv1" "srv2" "srv3")
CPU_SETS=("0" "1" "2")

# State tracking
busy_count=(0 0 0)           # busy counter for srv1, srv2, srv3
idle_count=(0 0 0)           # idle counter for srv1, srv2, srv3
running=(0 0 0)              # whether containers are running: 1 = running, 0 = stopped

# Initially run srv1
echo "Starting srv1..."
docker run -d --name srv1 --cpuset-cpus="0" -p 8081:8081 $IMAGE
running[0]=1

# Function to get CPU usage of a container
get_cpu_usage() {
    local cname=$1
    # Using `docker stats --no-stream` output parsing:
    # Example line: srv1 0.00%    ...
    local usage=$(docker stats --no-stream --format "{{.CPUPerc}}" $cname 2>/dev/null | tr -d '%' | tr -d ' ')
    if [ -z "$usage" ]; then
        usage=0
    fi
    echo "$usage"
}

# Function to start a container with correct CPU and port mapping
start_container() {
    local idx=$1
    local cname=${CONTAINERS[$idx]}
    local cpu=${CPU_SETS[$idx]}
    local port=$((8081 + $idx))  # e.g., srv2 could map 8082, etc. Or all can map 8081 if on different IPs
    echo "Starting $cname on CPU core #$cpu..."
    docker run -d --name $cname --cpuset-cpus="$cpu" $IMAGE
    running[$idx]=1
    # Depending on your Nginx setup, ensure Nginx can reach it. If using a user-defined bridge, it's automatic by container name.
}

# Function to stop a container
stop_container() {
    local idx=$1
    local cname=${CONTAINERS[$idx]}
    echo "Stopping $cname..."
    docker stop $cname && docker rm $cname
    running[$idx]=0
}

# Function to do a rolling update
# Logic: Pull new image. If updated, restart each running container one by one.
rolling_update() {
    echo "Checking for new image version..."
    local pull_output
    pull_output=$(docker pull $IMAGE 2>&1)
    if echo "$pull_output" | grep -q "Downloaded newer image"; then
        echo "New image available. Performing rolling update..."
        # Update containers in a rolling fashion:
        for i in "${!CONTAINERS[@]}"; do
            if [ "${running[$i]}" -eq 1 ]; then
                local cname=${CONTAINERS[$i]}
                echo "Updating $cname..."
                # Start a temporary container before stopping this one to ensure at least one always runs
                # If this is the last container, we can't stop it without starting another first.
                # Since we must keep at least one running, if this is srv1, we can do a trick:
                # Start a temporary container (like srv_temp), remove srv1, start srv1 again from new image, stop srv_temp
                # But for simplicity, assume we have at least two containers running. If only one running, skip update.
                
                if $( [ $i -eq 0 ] && [ "$(array_sum "${running[@]}")" -eq 1 ] ); then
                    # only srv1 is running, skip update now
                    echo "Only srv1 running, will delay update until scale up occurs."
                    continue
                fi

                # Start a temporary container if this is the only container running
                local temp_container=""
                if [ "$(array_sum "${running[@]}")" -eq 1 ]; then
                  # Only one container running, start a temporary one before stopping it
                  temp_container="srvtemp$$"
                  echo "Starting temporary container $temp_container..."
                  docker run -d --name $temp_container --cpuset-cpus="${CPU_SETS[0]}" $IMAGE
                fi
                
                # Now stop old container and start it with the new image
                docker stop $cname && docker rm $cname
                docker run -d --name $cname --cpuset-cpus="${CPU_SETS[$i]}" $IMAGE
                
                if [ -n "$temp_container" ]; then
                    # Stop the temporary container
                    echo "Stopping temporary container $temp_container..."
                    docker stop $temp_container && docker rm $temp_container
                fi
            fi
        done
    else
        echo "No new image version found."
    fi
}

# Helper function to sum array elements
array_sum() {
    local sum=0
    for val in "$@"; do
        sum=$((sum+val))
    done
    echo $sum
}

# Main monitoring loop
while true; do
    # Check each running container
    for i in "${!CONTAINERS[@]}"; do
        cname=${CONTAINERS[$i]}
        if [ "${running[$i]}" -eq 1 ]; then
            cpu_usage=$(get_cpu_usage $cname)
            if (( $(echo "$cpu_usage > $CPU_THRESHOLD_BUSY" | bc -l) )); then
                # Container is busy
                busy_count[$i]=$(( ${busy_count[$i]} + 1 ))
                idle_count[$i]=0
            elif (( $(echo "$cpu_usage < $CPU_THRESHOLD_IDLE" | bc -l) )); then
                # Container is idle
                idle_count[$i]=$(( ${idle_count[$i]} + 1 ))
                busy_count[$i]=0
            else
                # In-between: reset both counters
                busy_count[$i]=0
                idle_count[$i]=0
            fi
        fi
    done

    # Scaling logic:
    # If srv1 busy for 2 consecutive checks and srv2 not running, start srv2
    if [ ${busy_count[0]} -ge $CONSECUTIVE_THRESHOLD -a ${running[1]} -eq 0 ]; then
        start_container 1
    fi

    # If srv2 busy for 2 consecutive checks and srv3 not running, start srv3
    if [ ${busy_count[1]} -ge $CONSECUTIVE_THRESHOLD -a ${running[2]} -eq 0 ]; then
        start_container 2
    fi

    # If srv3 idle for 2 consecutive checks, stop srv3
    if [ ${idle_count[2]} -ge $CONSECUTIVE_THRESHOLD -a ${running[2]} -eq 1 ]; then
        stop_container 2
    fi

    # If srv2 idle for 2 consecutive checks, srv3 is not running, and srv2 is running, stop srv2
    if [ ${idle_count[1]} -ge $CONSECUTIVE_THRESHOLD -a ${running[1]} -eq 1 -a ${running[2]} -eq 0 ]; then
        stop_container 1
    fi

    # We never stop srv1 unless we are doing a rolling update. If only srv1 is running, do not stop it due to idle.

    # Periodically check for new version (e.g. once every 10 loops -> every 10 mins)
    # You can refine this schedule as needed.
    ((loop_count++))
    if [ $((loop_count % 10)) -eq 0 ]; then
        rolling_update
    fi

    sleep $CHECK_INTERVAL
done
