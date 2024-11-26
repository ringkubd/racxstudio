#!/bin/bash

# Define variables
PROJECT_DIR=$(pwd)
PARENT_DIR=$(dirname "$(pwd)")
PORT_FILE="$PARENT_DIR/port.txt"
PORT=$(cat "$PORT_FILE")
PM2_ID="node_$PORT"  # PM2 app identifier based on the custom port

# Check if the port.txt file exists and the port is not empty
if [ ! -f "$PORT_FILE" ]; then
  echo "Error: port.txt file not found."
  exit 1
fi

if [ -z "$PORT" ]; then
  echo "Error: port.txt is empty."
  exit 1
fi

# Change to the project directory
cd "$PROJECT_DIR" || { echo "Directory not found: $PROJECT_DIR"; exit 1; }

# Run git pull to get the latest code
echo "Running git pull..."
GIT_OUTPUT=$(GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no" git pull 2>&1)

# Print the output from the git pull command
echo "$GIT_OUTPUT"

# Normalize GIT_OUTPUT to avoid issues with spaces or newlines
GIT_OUTPUT=$(echo "$GIT_OUTPUT" | tr -d '\n' | sed 's/[[:space:]]\+/ /g')

# Check if git pull output indicates up-to-date
if echo "$GIT_OUTPUT" | grep -q "Already up to date."; then
  echo "No updates found."
  
  # Check if PM2 app exists for the given port
  pm2_id_exists=$(pm2 list | grep "$PM2_ID" | awk '{print $4}')
  
  if [ -n "$pm2_id_exists" ]; then
    # If the app exists, restart it with the custom port
    echo "PM2 app '$PM2_ID' exists. Restarting..."
    pm2 restart "$PM2_ID" --env PORT="$PORT" || { echo "PM2 restart failed"; exit 1; }
  else
    # If the app does not exist, start it with the custom port
    echo "PM2 app '$PM2_ID' does not exist. Starting..."
    pm2 start npm --name "$PM2_ID" -- start --env PORT="$PORT" || { echo "PM2 start failed"; exit 1; }
  fi

  echo "Deployment completed."
  exit 0
else
  # Check for git pull errors
  if echo "$GIT_OUTPUT" | grep -q "error"; then
    echo "An error occurred during git pull."
    exit 1
  fi

  # Run yarn to install dependencies
  echo "Running yarn install..."
  yarn || { echo "Yarn install failed"; exit 1; }

  # Run yarn build
  echo "Running yarn build..."
  yarn build || { echo "Yarn build failed"; exit 1; }

  # Check if PM2 app exists for the given port
  pm2_id_exists=$(pm2 list | grep "$PM2_ID" | awk '{print $4}')
  
  if [ -n "$pm2_id_exists" ]; then
    # If the app exists, restart it with the custom port
    echo "PM2 app '$PM2_ID' exists. Restarting..."
    pm2 restart "$PM2_ID" --env PORT="$PORT" || { echo "PM2 restart failed"; exit 1; }
  else
    # If the app does not exist, start it with the custom port
    echo "PM2 app '$PM2_ID' does not exist. Starting..."
    pm2 start npm --name "$PM2_ID" -- start --env PORT="$PORT" || { echo "PM2 start failed"; exit 1; }
  fi

  echo "Deployment completed."
fi

