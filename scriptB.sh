#!/bin/bash

# Function to make an HTTP request
make_request() {
    curl -i -X GET 127.0.0.1/compute
}

# Infinite loop to repeatedly make requests every 5 to 10 seconds
while true; do
    # Generate a random delay between 5 and 10 seconds
    delay=$((5 + RANDOM % 6))  # $RANDOM produces a number between 0 and 32767, % 6 makes it between 0 and 5, then add 5 to get 5 to 10.
    
    # Call the make_request function in the background and wait for the random delay
    make_request &

    # Wait for the random delay before making the next request
    sleep $delay
done

