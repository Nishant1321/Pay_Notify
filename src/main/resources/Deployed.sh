#!/bin/bash

# @author Ganesh Shinde
# @date 15-Apr-2026
# @since 1.0

# Function to exit script with an error message
exit_with_error() {
  echo "Error: $1"
  exit 1
}

# Prompt user for deployment choice
echo "Select deployment environment:"
echo "1) Live Server"
#echo "2) Test Server"
read -p "Enter choice [1-2]: " DEPLOYMENT_CHOICE

# Build the project using Maven
mvn clean package
if [ $? -ne 0 ]; then
  exit_with_error "Maven build failed."
fi

# Find the JAR file in the target directory
LOCAL_JAR_PATH=$(find ./target -name "*.jar" -type f -print -quit)
if [ -z "$LOCAL_JAR_PATH" ]; then
  exit_with_error "No JAR file found in the target directory."
fi

# Extract the JAR file name without the path
JAR_FILENAME=$(basename "$LOCAL_JAR_PATH")

# Define remote server details
ROOT_PASSWORD="Acme@123"
#ROOT_PASSWORD_TEST="Acme1234"
REMOTE_SERVER="root@217.216.78.208"
#REMOTE_SERVER_TEST="root@82.180.147.108"
REMOTE_PATH_LIVE="/home/Acme/AICEAppLive"
#REMOTE_PATH_TEST="/home/AICEAppTest"
LOCAL_PATH="/home/a/AICE_App_Test_Jar_Folder"
LOCAL_SERVICE_NAME="AICEapp_local.service"
LogLevel=ERROR

case $DEPLOYMENT_CHOICE in
1)
  # Ensure the remote directory exists on the Live server
  sshpass -p "$ROOT_PASSWORD" ssh "$REMOTE_SERVER" "mkdir -p \"$REMOTE_PATH_LIVE\""
  #sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_SERVER"
  #sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR "$REMOTE_SERVER"
  if [ $? -ne 0 ]; then
    exit_with_error "Failed to create remote directory on Live server."
  fi

  # Copy the JAR file to the Live server folder
  sshpass -p "$ROOT_PASSWORD" scp -r "$LOCAL_JAR_PATH" $REMOTE_SERVER:"$REMOTE_PATH_LIVE/"
  if [ $? -ne 0 ]; then
    exit_with_error "SCP transfer to Live server failed."
  fi

  # SSH into the remote server and create a systemd service for Live
  sshpass -p "$ROOT_PASSWORD" ssh -T "$REMOTE_SERVER" <<EOF
  # Check if the service is running and stop it for testing purposes
  if sudo systemctl is-active AICEapp_live.service >/dev/null; then
    sudo systemctl stop AICEapp_live.service
  fi
  # Create the systemd service file for Live environment
  sudo bash -c 'cat > /etc/systemd/system/AICEapp_live.service' <<EOL
[Unit]
Description=Java Application Service (Live)
After=network.target

[Service]
User=root
#ExecStart=/usr/lib/jvm/openlogic-openjdk-17-hotspot/bin/java -jar "$REMOTE_PATH_LIVE/$JAR_FILENAME" --server.port=8443
ExecStart=/usr/bin/java -jar /home/Acme/AICEAppLive/campaign-crm-0.0.1-SNAPSHOT.jar --server.port=8443
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

  sudo systemctl daemon-reload
  sudo systemctl enable AICEapp_live.service
  sudo systemctl start AICEapp_live.service
EOF
  ;;
#2)
#  # Ensure the remote directory exists on the Test server
#  sshpass -p "$ROOT_PASSWORD_TEST" ssh "$REMOTE_SERVER_TEST" "mkdir -p \"$REMOTE_PATH_TEST\""
#  if [ $? -ne 0 ]; then
#    exit_with_error "Failed to create remote directory on Test server."
#  fi
#
#  # Copy the JAR file to the Test server folder
#  sshpass -p "$ROOT_PASSWORD_TEST" scp -r "$LOCAL_JAR_PATH" $REMOTE_SERVER_TEST:"$REMOTE_PATH_TEST/"
#  if [ $? -ne 0 ]; then
#    exit_with_error "SCP transfer to Test server failed."
#  fi
#
#  # SSH into the remote server and create a systemd service for Test
#  sshpass -p "$ROOT_PASSWORD_TEST" ssh -T "$REMOTE_SERVER_TEST" <<EOF
#
#  # Check if the service is running and stop it for testing purposes
#  if sudo systemctl is-active AICEapp_test.service >/dev/null; then
#    sudo systemctl stop AICEapp_test.service
#  fi
#  # Create the systemd service file for Test environment
#  sudo bash -c 'cat > /etc/systemd/system/AICEapp_test.service' <<EOL
#[Unit]
#Description=Java Application Service (Test)
#After=network.target
#
#[Service]
#User=root
#ExecStart=/usr/lib/jvm/java-17-openjdk-17.0.14.0.7-3.el8.x86_64/bin/java -jar "$REMOTE_PATH_TEST/$JAR_FILENAME" --server.port=8443
#Restart=always
#RestartSec=10
#
#[Install]
#WantedBy=multi-user.target
#EOL
#
#  sudo systemctl daemon-reload
#  sudo systemctl enable AICEapp_test.service
#  sudo systemctl start AICEapp_test.service
#EOF
#  ;;
*)
  echo "Invalid option selected."
  exit 1
  ;;
esac

echo "Deployment process completed successfully."
