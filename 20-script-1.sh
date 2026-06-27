#!/bin/bash

# NAME=INDIA
# echo "My Country Name: $NAME"
# echo "PID of script-1: $$"
# sh 21-script-2.sh
# Here ☝️ script-1 is calling script-2 and passing the variable NAME to it. But script-2 is not able to access the variable NAME.
# Here 👇 is the output of the above script 
# sh 20-script-1.sh
# My Country Name: INDIA
# PID of script-1: 6410
# My Country Name:
# PID of script-2: 6411

NAME=INDIA
echo "My Country Name: $NAME"
echo "PID of script-1: $$"
source ./21-script-2.sh # Here 👆 we are using source command to call script-2. This will make the variable NAME accessible to script-2. Now script-2 will be able to access the variable NAME and print it. But How? For That Go to session 19 at timestamp 52:00