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

dnf install python3 gcc python3-devel -y &>>$LOG_FILE &
pid=$!
spinner $pid "Installing Python3"
wait $pid
VALIDATE $? "Installing Python3"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    # ONLY runs if the user does NOT exist
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE &
    pid=$!
    spinner $pid "Setting up roboshop User"
    wait $pid
    VALIDATE $? "Setting up roboshop User"
else
    # Runs safely if the user is already there
    echo -e "User roboshop already exists...${Y}SKIPPING$N creation of roboshop user" | tee -a $LOG_FILE
fi

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "Setting up Application Directory"

rm -rf /app/* &>>$LOG_FILE
VALIDATE $? "Removing existing Application Code"

curl -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip &>>$LOG_FILE &
pid=$!
spinner $pid "Downloading Application Code"
wait $pid
VALIDATE $? "Downloading Application Code"

cd /app 
unzip /tmp/payment.zip &>>$LOG_FILE
VALIDATE $? "Extracting Application Code"

cd /app 
pip3 install -r requirements.txt &>>$LOG_FILE &
pid=$!
spinner $pid "Installing Python3 Dependencies"
wait $pid
VALIDATE $? "Installing Python3 Dependencies"

cp $SCRIPT_DIR/payment.service /etc/systemd/system/payment.service &>>$LOG_FILE
VALIDATE $? "Copying SystemD Service File"

systemctl daemon-reload &>>$LOG_FILE &
pid=$!
spinner $pid "Reloading SystemD Daemon"
wait $pid
VALIDATE $? "Reloading SystemD Daemon"

systemctl enable payment &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling Payment Service"
wait $pid  
VALIDATE $? "Enabling Payment Service"

systemctl start payment &>>$LOG_FILE &
pid=$!
spinner $pid "Starting Payment Service"
wait $pid
VALIDATE $? "Starting Payment Service"

systemctl restart payment &>>$LOG_FILE
VALIDATE $? "Restarting Payment Service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo "Script execution completed at: $(date)" | tee -a $LOG_FILE
echo "Total time taken: $TOTAL_TIME seconds" | tee -a $LOG_FILE