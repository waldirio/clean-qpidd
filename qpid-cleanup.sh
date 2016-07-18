#!/bin/bash


#
# Date ......: 07/18/2016
# Developer .: Chris Roberts <chrobert@redhat.com>
# Purpose ...: Remove queues unsed from qpidd
# Changelog .:
#              07/18/2016 - Review in the bash script for Waldirio M Pinheiro <waldirio@redhat.com>
#              - Test authentication before create the list and remove
#	       - Generate log file from the commands (/var/log/qpid-clean.log)
#	       - Log Start and Finish time
# 	       - Generate a report of all queues deleted.

# VARIABLES

satUser="admin"					# Satellite Admin User
satPassword="redhat"				# Satellite Admin Password
maxperpage=10000 				# Maximum content hosts or organizations in your Satellite
HAMMER="hammer"
HOSTNAMEF=$(hostname -f)
contenthostsfile=content-hosts.txt
qpidqueuesfile=qpid-queues-uuids.txt
LOG="/var/log/qpid-clean.log"
LOCALDATE="date +%M-%d-%Y-%H-%M-%S"
# ########################################################################################################


test_conn()
{
  echo "Started $($LOCALDATE)"							| tee -a $LOG
  # Clean screen
  clear
  $HAMMER -u $satUser -p $satPassword user list 2>/dev/null 1>/dev/null
  testResult=$(echo $?)
  if [ $testResult -ne 0 ]; then
    echo "User and/or Password is wrong, please update them ..."		| tee -a $LOG 
    echo "exiting ......"							| tee -a $LOG 
    echo "Finished $($LOCALDATE)"						| tee -a $LOG
    echo "================================================================="	| tee -a $LOG
    exit 1
  else
    echo "User and Password are correct"					| tee -a $LOG
    echo "please wait a few seconds ...."					| tee -a $LOG
    echo ""									| tee -a $LOG
    queue_clean
  fi
}

queue_clean()
{
  #generate content hosts UUIDs
  rm -f $contenthostsfile
  echo "finding organizations"
  for org in $($HAMMER -u $satUser -p $satPassword organization list --per-page=${maxperpage} | grep " | " | grep -v "^ID" | awk '{ print $3 }')
  do
    echo "finding content hosts in organization $org"
    hammer -u $satUser -p $satPassword content-host list --organization=${org} --per-page=${maxperpage} | grep " | " | grep -v "^ID" | awk '{ print $1 }' >> $contenthostsfile
  done


  #sort the UUIDs
  sort $contenthostsfile > ${contenthostsfile}.sorted
  mv -f ${contenthostsfile}.sorted $contenthostsfile
  #find pulp.admin.* queues and remember just the (only relevant) UUID
  echo "finding qpid queues for pulp consumers"
  ls -1 /var/lib/qpidd/qls/jrnl/ /var/lib/qpidd/.qpidd/qls/jrnl/ 2> /dev/null | grep "^pulp.agent" | cut -d'.' -f3 | sort > $qpidqueuesfile
  echo "found $(wc -l $contenthostsfile | cut -d' ' -f1) content hosts and $(wc -l $qpidqueuesfile | cut -d' ' -f1) qpid queues for pulp consumers"					| tee -a $LOG
  echo "list of content hosts: $contenthostsfile, list of qpid queues: $qpidqueuesfile"	            											| tee -a $LOG
  echo "- please remove the files once you dont need them"																| tee -a $LOG
  echo -n "Delete orphaned queues with no matching content host UUID (y/n)? "														| tee -a $LOG
  read answer
  echo ""									| tee -a $LOG
  echo ""									| tee -a $LOG

  if echo "$answer" | grep -iq "^y" ; then
    for uuid in $(diff $contenthostsfile $qpidqueuesfile | grep "^> " | cut -d' ' -f2)
    do
      queue="pulp.agent.${uuid}"
      echo "deleting queue $queue"																			| tee -a $LOG
      qpid-config --ssl-certificate /etc/pki/katello/certs/java-client.crt --ssl-key /etc/pki/katello/private/java-client.key -b "amqps://${HOSTNAMEF}:5671" del queue $queue --force	| tee -a $LOG
    done
  fi
  echo "Finished $($LOCALDATE)"							| tee -a $LOG
  echo "================================================================="	| tee -a $LOG
  echo "Check the output in $LOG"
  echo ""
}


# Main
test_conn
