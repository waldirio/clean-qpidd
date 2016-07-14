[root@saplsatellite02 ~]# more qpid-cleanup.sh
#!/bin/bash
#name of the user to query Satellite
satuser="admin"
#password of the user
satpassword="password_here"
#maximum content hosts or organizations in your Satellite
maxperpage=10000
contenthostsfile=content-hosts.txt
qpidqueuesfile=qpid-queues-uuids.txt
#generate content hosts UUIDs
rm -f $contenthostsfile
echo "finding organizations"
for org in $(hammer -u $satuser -p $satpassword organization list --per-page=${maxperpage} | grep " | " | grep -v "^ID" | awk '{ print $3 }'); do
echo "finding content hosts in organization $org"
hammer -u $satuser -p $satpassword content-host list --organization=${org} --per-page=${maxperpage} | grep " | " | grep -v "^ID" | awk '{ print $1 }' >> $contenthostsfile
done
#sort the UUIDs
sort $contenthostsfile > ${contenthostsfile}.sorted
mv -f ${contenthostsfile}.sorted $contenthostsfile
#find pulp.admin.* queues and remember just the (only relevant) UUID
echo "finding qpid queues for pulp consumers"
ls -1 /var/lib/qpidd/qls/jrnl/ /var/lib/qpidd/.qpidd/qls/jrnl/ 2> /dev/null | grep "^pulp.agent" | cut -d'.' -f3 | sort > $qpidqueuesfile
echo "found $(wc -l $contenthostsfile | cut -d' ' -f1) content hosts and $(wc -l $qpidqueuesfile | cut -d' ' -f1) qpid queues for pulp consumers"
echo "list of content hosts: $contenthostsfile, list of qpid queues: $qpidqueuesfile"
echo "- please remove the files once you dont need them"
echo -n "Delete orphaned queues with no matching content host UUID (y/n)? "
read answer
if echo "$answer" | grep -iq "^y" ; then
export HOSTNAMEF=$(hostname -f)
for uuid in $(diff $contenthostsfile $qpidqueuesfile | grep "^> " | cut -d' ' -f2); do
queue="pulp.agent.${uuid}"
echo "deleting queue $queue"
qpid-config --ssl-certificate /etc/pki/katello/certs/java-client.crt --ssl-key /etc/pki/katello/private/java-client.key -b "amqps://${HOSTNAMEF}:5671" del queue $queue --force
done
fi
[root@saplsatellite02 ~]#
