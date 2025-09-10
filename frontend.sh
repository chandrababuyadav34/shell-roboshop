#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# Check if script is run as root
if [ $USERID -ne 0 ]; then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1
else
    echo -e "$G You are running with root access $N" | tee -a $LOG_FILE
fi

# Validate function
VALIDATE(){
    if [ $1 -eq 0 ]; then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

# Check if port 80 is in use
echo "Checking if port 80 is in use..." | tee -a $LOG_FILE
if lsof -i :80 &>>$LOG_FILE; then
    echo -e "$Y Port 80 is in use, killing the process... $N" | tee -a $LOG_FILE
    fuser -k 80/tcp &>>$LOG_FILE
    VALIDATE $? "Clearing port 80"
else
    echo -e "$G Port 80 is free $N" | tee -a $LOG_FILE
fi

dnf module disable nginx -y &>>$LOG_FILE
VALIDATE $? "Disabling Default Nginx"

dnf module enable nginx:1.24 -y &>>$LOG_FILE
VALIDATE $? "Enabling Nginx:1.24"

dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installing Nginx"

systemctl enable nginx &>>$LOG_FILE

# Clean up stale PID file if exists
if [ -f /run/nginx.pid ]; then
    echo "Removing stale nginx PID file..." | tee -a $LOG_FILE
    rm -f /run/nginx.pid &>>$LOG_FILE
    VALIDATE $? "Removing nginx PID file"
fi

systemctl start nginx &>>$LOG_FILE
VALIDATE $? "Starting Nginx"

# Clean old web files
rm -rf /usr/share/nginx/html/* &>>$LOG_FILE
VALIDATE $? "Removing default web content"

# Download and unzip frontend content
curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading frontend"

mkdir -p /usr/share/nginx/html &>>$LOG_FILE
cd /usr/share/nginx/html || exit
unzip /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Unzipping frontend content"

# Replace nginx.conf
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak &>>$LOG_FILE
VALIDATE $? "Backing up original nginx.conf"

rm -f /etc/nginx/nginx.conf &>>$LOG_FILE
cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>$LOG_FILE
VALIDATE $? "Copying custom nginx.conf"

# Test NGINX config before restarting
echo "Testing nginx configuration..." | tee -a $LOG_FILE
nginx -t &>>$LOG_FILE
VALIDATE $? "Nginx configuration test"

# Restart NGINX
systemctl restart nginx &>>$LOG_FILE
VALIDATE $? "Restarting Nginx"

echo -e "$G ✅ Frontend deployment completed successfully $N" | tee -a $LOG_FILE