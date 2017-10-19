#!/bin/bash

thread_num=2
counter=0
pids=""
for i in testdir/*.a
do
 counter=`echo "$counter + 1"|bc`
 echo $i $counter
 cat $i &
 pids+="$! "
 if [[ "$counter" -eq "$thread_num" ]]; then
 echo "$thread_num reached"
 counter=0
 fi
done
  
