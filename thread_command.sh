#!/bin/bash

thread_num=2
counter=0
pids=""
for i in 1 2 3 4 5 6 7 8 9 
do
 echo "$i - location in the loop"
 echo "Captured pid $pids"
 while [ "$counter" -eq "$thread_num" ]
 do
  echo "$counter - num of thread right now"
  echo "Should pause here since thread running is equal to the thread_num var"
  sleep 1
  for j in $pids
  do
   running_pid_flag=`ps -ef | grep $j| grep -v grep| wc -l`
   ps -ef | grep $j| grep -v grep
   if [ "$running_pid_flag" -eq "0" ]; then
    if [ "$counter" -ne "0" ]; then
     counter=`echo "$counter - 1"|bc`
    fi
   fi
  done
  echo "$counter - new value of counter after passing the test"
 done
 if [ "$counter" -eq "$thread_num" ]; then
  echo "$thread_num reached"
 else
  #This is the execute
  sleep 10 &
  pids="$pids $!"
  counter=`echo "$counter + 1"|bc`
 fi
done

