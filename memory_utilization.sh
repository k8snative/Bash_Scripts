#!/bin/bash

# Set the memory threshold in percentage
threshold=90

# Get the system's free memory percentage
free_percent=$(free -m | awk 'NR==2 {printf "%.0f", $3*100/$2}')

# Log file path
log_file="/var/www/check_backend_application_crashed/memory_utilization.log"

# Check if the memory utilization is over the threshold
if [ "$free_percent" -gt "$threshold" ]; then
    # Restart PM2
    pm2 restart all
    echo "$(date): PM2 restarted due to high memory utilization." >> "$log_file"
#else
#    echo "$(date): Memory utilization is below the threshold. No action taken." >> "$log_file"
fi