#!/bin/bash

while sleep 1; do
	now=$(date -I'seconds')
	temperature=$(vcgencmd measure_temp)
	echo "[$now] $temperature"
done
