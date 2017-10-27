#!/bin/bash

thread_num=2
counter=0
pids=""

#Get random number, will not be needed in actual script.
get_ran () {
output_num=`echo ${RANDOM:0:1}`
echo $output_num
}

for i in 1 2 3 4 5 
do
 echo "$i - location in the loop"
 if [ "$counter" -eq "$thread_num" ]; then
  echo "$thread_num reached"
 else
  #This is the execute
  sleep "$(get_ran)" &
  curr_pid="$!"
  pids="$pids $curr_pid"
  echo "Captured pid $pids"
  counter=`echo "$counter + 1"|bc`
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
	 echo "The pid $j is not existing anymore, removing it from pid list"
     if [ "$counter" -ne "0" ]; then
      counter=`echo "$counter - 1"|bc`
      pids=`echo ${pids/$j/}`
      echo "Old pids gone, here are the new pids: $pids"
     fi
    fi
   done
  echo "$counter - new value of counter after passing the test"
 done
 fi
done
