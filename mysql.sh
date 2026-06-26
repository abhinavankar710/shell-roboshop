#!/bin/bash

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 $((${#spinstr}-1))); do
            printf "\r$2... [%c]" "${spinstr:$i:1}"
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

dnf list installed mysql-server &>>$LOG_FILE 
if [ $? -ne 0 ]; then  
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y mysql-server &>>$LOG_FILE
        echo $? > /tmp/mysql_status
    ) & 
    
    pid=$!
    spinner $pid "Installing MySQL"
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/mysql_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "MySQL Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "MySQL already exists$Y SKIPPING$N installation of MySQL" | tee -a $LOG_FILE
fi

systemctl enable mysqld &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling MySQL Service"
wait $pid
VALIDATE $? "Enabling MySQL Service"

systemctl start mysqld &>>$LOG_FILE &
pid=$!
spinner $pid "Starting MySQL Service"
wait $pid
VALIDATE $? "Starting MySQL Service"

mysql_secure_installation --set-root-pass RoboShop@1

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo "Script execution completed at: $(date)" | tee -a $LOG_FILE
echo "Total time taken: $TOTAL_TIME seconds" | tee -a $LOG_FILE