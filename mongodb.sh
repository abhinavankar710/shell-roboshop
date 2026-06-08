#!/bin/bash

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 $((${#spinstr}-1))); do
            printf "\rInstalling MongoDB... [%c]" "${spinstr:$i:1}"
            sleep $delay
        done
    done
    printf "\r\033[K"
}

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $USERID -ne 0 ]; then
    echo "ERROR: Please run this script with root privileges"
    exit 1
fi

LOGS_FOLDER="/var/log/shell-roboshop"
SCRIPT_NAME=$( echo $0 | cut -d "." -f1 )
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
mkdir -p $LOGS_FOLDER
echo "Script execution started at: $(date)" | tee -a $LOG_FILE

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R✗ Failed$N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$2...$G✓ Success$N" | tee -a $LOG_FILE
    fi
}

cp mongo.repo /etc/yum.repos.d/mongo.repo &>>$LOG_FILE
VALIDATE $? "MongoDB Repository Setup"

dnf list installed mongodb-org &>>$LOG_FILE
if [ $? -ne 0 ]; then
    echo -ne "${Y}Installing${N} MongoDB"
    
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y mongodb-org &>>$LOG_FILE
        echo $? > /tmp/mongo_status
    ) & 
    
    pid=$!
    spinner $pid
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/mongo_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "MongoDB Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "MongoDB already exists$Y SKIPPING$N installation of MongoDB" | tee -a $LOG_FILE
fi

systemctl enable mongod &>>$LOG_FILE
VALIDATE $? "Enabling MongoDB Service"

systemctl start mongod &>>$LOG_FILE
VALIDATE $? "Starting MongoDB Service"