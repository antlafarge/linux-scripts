#!/bin/sh
while sleep 1; do
	now=$(date)
	temperature=$(vcgencmd measure_temp)
	message="[$now] $temperature"
	echo "$message"
	echo "$message" >> pi-cpu-temperature.log
done
