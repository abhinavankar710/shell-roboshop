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
START_TIME=$(date +%s)
echo "Script execution started at: $(date)" | tee -a $LOG_FILE

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "${N}$2...$R✗ Failed$N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "${N}$2...$G✓ Success$N" | tee -a $LOG_FILE
    fi
}

dnf module disable redis -y &>>$LOG_FILE
pid=$!
spinner $pid "Disabling Default Redis Module"
wait $pid
VALIDATE $? "Disabling Default Redis Module"

dnf module enable redis:7 -y &>>$LOG_FILE
pid=$!
spinner $pid "Enabling Redis 7 Module"
wait $pid
VALIDATE $? "Enabling Redis 7 Module"

dnf list installed redis &>>$LOG_FILE
if [ $? -ne 0 ]; then
    echo -ne "${Y}Installing${N} Redis"
    
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y redis &>>$LOG_FILE
        echo $? > /tmp/redis_status
    ) & 
    
    pid=$!
    spinner $pid
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/redis_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "Redis Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "Redis already exists$Y SKIPPING$N installation of Redis" | tee -a $LOG_FILE
fi

sed -i 's/127.0.0.1/0.0.0.0/g' -e '/protected-mode/ c protected-mode no' /etc/redis/redis.conf &>>$LOG_FILE
pid=$!
spinner $pid "Allowing Remote Connections to Redis"
wait $pid
VALIDATE $? "Allowing Remote Connections to Redis"
pid=$!
spinner $pid "Disabling Redis Protected Mode"
wait $pid
VALIDATE $? "Disabling Redis Protected Mode"

systemctl enable redis &>>$LOG_FILE
pid=$!
spinner $pid "Enabling Redis Service"
wait $pid
VALIDATE $? "Enabling Redis"

systemctl start redis &>>$LOG_FILE
pid=$!
spinner $pid "Executing Redis Service"
wait $pid
VALIDATE $? "Executing Redis"

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo "Script execution completed at: $(date)" | tee -a $LOG_FILE
echo "Total time taken: $TOTAL_TIME seconds" | tee -a $LOG_FILE