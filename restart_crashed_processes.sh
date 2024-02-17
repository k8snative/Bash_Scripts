#!/bin/bash

# Run pm2 log, grep for lines containing "crashed", extract process IDs, and restart them

# Capture the output of pm2 log and grep for lines containing "crashed"
export PATH="/root/.nvm/versions/node/v18.13.0/bin/:$PATH"
while read -r line
do
    # Check if the line contains "crashed"
    if [[ $line == *crashed* ]]; then
        # Extract process ID from the log line
        process_id=$(echo $line | awk -F"|" '{print $1}' | tr -d '[:space:]')

        # Restart the process using pm2 restart
        # Uncomment the following line when you are ready to actually restart the processes
        pm2 restart $process_id

        echo "Restarted process $process_id"
    fi
done < <(pm2 log)