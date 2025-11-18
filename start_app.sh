#!/bin/bash
set -e

# Navigate to app directory
cd "$(dirname "$0")"

# Kill any existing instance
pkill -f 'python app.py' || true
sleep 1

# Start the app in background
nohup python app.py > app.log 2>&1 &
PID=$!

# Save PID
echo $PID > app.pid
echo "Started Flask app with PID: $PID"

# Wait a moment and verify it's still running
sleep 2
if kill -0 $PID 2>/dev/null; then
    echo "App is running successfully!"
    exit 0
else
    echo "App failed to start. Check app.log for details."
    exit 1
fi
This script will start the web app in a background process and save the PID to a file. It will also verify that the app is running successfully.

We will now create the deployment workflow. On the local folder hello-world-flask-app, create a new folder named .github and inside it create a new folder named workflows and inside it create a new file named deploy.yml containing the following code:

name: Deploy to GCP VM

on:
  push:
    branches: ["main"]
  workflow_dispatch:

env:
  APP_DIR: /home/${{ secrets.GCP_VM_USER }}/apps/hello_world_flask_gcp

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.9.0
      with:
        ssh-private-key: ${{ secrets.GCP_SSH_PRIVATE_KEY }}

    - name: Add VM to known_hosts
      run: ssh-keyscan -H ${{ secrets.GCP_VM_IP }} >> ~/.ssh/known_hosts

    - name: Deploy code to VM
      run: |
        ssh ${{ secrets.GCP_VM_USER }}@${{ secrets.GCP_VM_IP }} "mkdir -p ${{ env.APP_DIR }}"
        rsync -az --exclude ".git" --exclude ".github" ./ ${{ secrets.GCP_VM_USER }}@${{ secrets.GCP_VM_IP }}:${{ env.APP_DIR }}/

    - name: Install dependencies
      run: |
        ssh ${{ secrets.GCP_VM_USER }}@${{ secrets.GCP_VM_IP }} "
          cd ${{ env.APP_DIR }}
          sudo apt-get install -y python3 python3-pip
          sudo pip install -r requirements.txt
        "

    - name: Start application
      run: |
        ssh ${{ secrets.GCP_VM_USER }}@${{ secrets.GCP_VM_IP }} "
          cd ${{ env.APP_DIR }}
          chmod +x start_app.sh
          ./start_app.sh
        "

    - name: Verify deployment
      run: |
        ssh ${{ secrets.GCP_VM_USER }}@${{ secrets.GCP_VM_IP }} "
          curl -f http://localhost:5000/
          echo 'Deployment successful!'
        "