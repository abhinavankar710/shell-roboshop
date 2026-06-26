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
SCRIPT_DIR=$PWD
MONGODB_HOST="mongodb.ankar.space"
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
mkdir -p $LOGS_FOLDER
START_TIME=$(date +%s)
echo "Script execution started at: $(date)" | tee -a $LOG_FILE

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R✗ Failed$N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$2...$G✓ Success$N" | tee -a $LOG_FILE
    fi
}

dnf module disable nginx -y &>>$LOG_FILE &
pid=$!
spinner $pid "Disabling Default Nginx Module"
wait $pid
VALIDATE $? "Disabling Default Nginx Module"

dnf module enable nginx:1.24 -y &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling Nginx 1.24 Module"
wait $pid
VALIDATE $? "Enabling Nginx 1.24 Module"

dnf list installed nginx &>>$LOG_FILE 
if [ $? -ne 0 ]; then  
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y nginx &>>$LOG_FILE
        echo $? > /tmp/nginx_status
    ) & 
    
    pid=$!
    spinner $pid "Installing Nginx"
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/nginx_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "Nginx Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "Nginx already exists$Y SKIPPING$N installation of Nginx" | tee -a $LOG_FILE
fi

systemctl enable nginx &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling Nginx Service"
wait $pid
VALIDATE $? "Enabling Nginx Service"

systemctl start nginx &>>$LOG_FILE &
pid=$!
spinner $pid "Starting Nginx Service"
wait $pid
VALIDATE $? "Starting Nginx Service"

rm -rf /usr/share/nginx/html/* &>>$LOG_FILE &
VALIDATE $? "Removing Default Nginx Content"

curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE &
pid=$!
spinner $pid "Downloading Frontend Code"
wait $pid
VALIDATE $? "Downloading Frontend Code"

cd /usr/share/nginx/html 
unzip /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Extracting Frontend Code"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>$LOG_FILE &

systemctl restart nginx &>>$LOG_FILE &
pid=$!
spinner $pid "Restarting Nginx Service"
wait $pid
VALIDATE $? "Restarting Nginx Service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo "Script execution completed at: $(date)" | tee -a $LOG_FILE
echo "Total time taken: $TOTAL_TIME seconds" | tee -a $LOG_FILE