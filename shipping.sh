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

dnf install maven -y &>>$LOG_FILE &
pid=$!
spinner $pid "Installing Maven"
wait $pid
VALIDATE $? "Installing Maven"

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

curl -L -o /tmp/shipping.zip https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading Application Code"

cd /app 
unzip /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "Extracting Application Code"

cd /app 
mvn clean package &>>$LOG_FILE
VALIDATE $? "Downloading Dependencies"
mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service &>>$LOG_FILE
VALIDATE $? "Copying SystemD Service File"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading SystemD Daemon"

systemctl enable shipping &>>$LOG_FILE
VALIDATE $? "Enabling Shipping Service"

systemctl start shipping &>>$LOG_FILE
VALIDATE $? "Starting Shipping Service"

dnf list installed mysql &>>$LOG_FILE 
if [ $? -ne 0 ]; then  
    # --- THE FIX STARTS HERE ---
    # We run the install AND save the exit code to a file inside this block ( )
    (
        dnf install -y mysql &>>$LOG_FILE
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

mysql -h mysql.ankar.space -uroot -pRoboShop@1 -e "use cities" &>>$LOG_FILE
if [ $? -ne 0 ]; then
    mysql -h mysql.ankar.space -uroot -pRoboShop@1 < /app/db/schema.sql &>>$LOG_FILE
    VALIDATE $? "Loading Schema"

    mysql -h mysql.ankar.space -uroot -pRoboShop@1 < /app/db/app-user.sql &>>$LOG_FILE
    VALIDATE $? "Loading App User"

    mysql -h mysql.ankar.space -uroot -pRoboShop@1 < /app/db/master-data.sql &>>$LOG_FILE
    VALIDATE $? "Loading Master Data"
else
    echo -e "Shipping data already loaded ...{$Y}SKIPPING$N" | tee -a $LOG_FILE
fi


systemctl restart shipping &>>$LOG_FILE
VALIDATE $? "Restarting Shipping Service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))
echo "Script execution completed at: $(date)" | tee -a $LOG_FILE
echo "Total time taken: $TOTAL_TIME seconds" | tee -a $LOG_FILE