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
echo "Script execution started at: $(date)" | tee -a $LOG_FILE

VALIDATE(){
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R✗ Failed$N" | tee -a $LOG_FILE
        exit 1
    else
        echo -e "$2...$G✓ Success$N" | tee -a $LOG_FILE
    fi
}

dnf module disable nodejs -y &>>$LOG_FILE &
pid=$! 
spinner $pid "Disabling Default NodeJS Module"
wait $pid

VALIDATE $? "Disabling Default NodeJS Module"

dnf module enable nodejs:20 -y &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling NodeJS 20 Module"
wait $pid
VALIDATE $? "Enabling NodeJS 20 Module"

dnf list installed nodejs &>>$LOG_FILE 
if [ $? -ne 0 ]; then  
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y nodejs &>>$LOG_FILE
        echo $? > /tmp/nodejs_status
    ) & 
    
    pid=$!
    spinner $pid "Installing NodeJS"
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/nodejs_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "NodeJS Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "NodeJS already exists$Y SKIPPING$N installation of NodeJS" | tee -a $LOG_FILE
fi

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

mkdir /app &>>$LOG_FILE
VALIDATE $? "Setting up Application Directory"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOG_FILE &
pid=$!
spinner $pid "Downloading Application Code"
wait $pid
VALIDATE $? "Downloading Application Code"

cd /app
VALIDATE $? "Changing to application Directory"

rm -rf /app/* &>>$LOG_FILE
VALIDATE $? "Removing existing Application Code"

unzip -o /tmp/catalogue.zip &>>$LOG_FILE &
pid=$!
spinner $pid "Extracting Application Code"
wait $pid
VALIDATE $? "Extracting Application Code"

cd /app 
npm install &>>$LOG_FILE &
pid=$!
spinner $pid "Installing NodeJS Dependencies"
wait $pid
VALIDATE $? "Installing NodeJS Dependencies"

cp $SCRIPT_DIR/catalogue.service /etc/systemd/system/catalogue.service &>>$LOG_FILE
VALIDATE $? "Copying SystemD Catalogue Service File"

systemctl daemon-reload &>>$LOG_FILE &
pid=$!
spinner $pid "Reloading SystemD"
wait $pid
VALIDATE $? "Reloading SystemD"

systemctl enable catalogue &>>$LOG_FILE &
pid=$!
spinner $pid "Enabling Catalogue Service"
wait $pid
VALIDATE $? "Enabling Catalogue Service"

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/mongo.repo &>>$LOG_FILE 
VALIDATE $? "Setting up MongoDB Repository File"

dnf list installed mongodb-mongosh -y &>>$LOG_FILE

if [ $? -ne 0 ]; then
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y mongodb-mongosh &>>$LOG_FILE
        echo $? > /tmp/mongosh_status
    ) & 
    
    pid=$!
    spinner $pid "Installing MongoDB Client"
    wait $pid
    
    # We read the code from the file so it is NEVER empty
    EXIT_STATUS=$(cat /tmp/mongosh_status)
    
    # We validate using that solid number
    VALIDATE $EXIT_STATUS "MongoDB Client Installation"
    # --- THE FIX ENDS HERE ---
    
else
    echo -e "MongoDB Client already exists$Y SKIPPING$N installation of MongoDB Client" | tee -a $LOG_FILE
fi

INDEX=$(mongosh mongodb.ankar.space --quiet --eval "db.getMongo().getDBNames().indexOf('catalogue')" 2>>$LOG_FILE)
if [ $INDEX -lt 0 ]; then
    mongosh --host $MONGODB_HOST --file /app/db/master-data.js &>>$LOG_FILE &
    pid=$!
    spinner $pid "Importing Master Data to MongoDB"
    wait $pid
    VALIDATE $? "Importing Master Data to MongoDB"
else
    echo -e "Master data already exists$Y SKIPPING$N import" | tee -a $LOG_FILE
fi

systemctl restart catalogue &>>$LOG_FILE &
pid=$!
spinner $pid "Restarting Catalogue Service"
wait $pid
VALIDATE $? "Restarting Catalogue Service"

echo -e "\n${G}Catalogue Service Setup Completed Successfully${N}\n" | tee -a $LOG_FILE