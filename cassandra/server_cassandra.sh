kill()
{
echo "killing the all active server instance..."
killall -w java
sleep 3
tmux kill-session -t session_test
sleep 3
echo "all the server session has been killed."
}

ip1()
{
echo "Aasigning the IP address to interfaces..."
ifconfig ens1f0np0:1 10.75.119.33 up 
ifconfig ens1f0np0:2 10.75.119.34 up 
ifconfig ens1f0np0:3 10.75.119.35 up 
ifconfig ens1f0np0:4 10.75.119.36 up  
ifconfig ens1f0np0:5 10.75.119.38 up 
ifconfig ens1f0np0:6 10.75.119.39 up 
ifconfig ens1f0np0:7 10.75.119.40 up
}

ip2()
{
echo "Aasigning the IP address to interfaces..."
ip addr add 10.75.119.37 dev ens1f0np0
ip addr add 10.75.119.38 dev ens1f1np1
ip addr add 10.75.119.39 dev ens26f0np0
ip addr add 10.75.119.40 dev ens26f1np1
}

mnt()
{
echo "Mounting the Nvme Drives..."
mount /dev/nvme1n1 /mnt/nvme1
mount /dev/nvme2n1 /mnt/nvme2
mount /dev/nvme3n1 /mnt/nvme3
mount /dev/nvme4n1 /mnt/nvme4
}

mem()
{
echo "Binding the memory with hugepages ..." 
echo 280000 > /proc/sys/vm/nr_hugepages
cat /proc/sys/vm/nr_hugepages
}

network()
{

echo "Configuring the Network Settings ..." 

ulimit -n 1000000
ulimit -l unlimited
sysctl -w \
net.ipv4.tcp_keepalive_time=60 \
net.ipv4.tcp_keepalive_probes=3 \
net.ipv4.tcp_keepalive_intvl=10
sysctl -w \
net.core.rmem_max=16777216 \
net.core.wmem_max=16777216 \
net.core.rmem_default=16777216 \
net.core.wmem_default=16777216 \
net.core.optmem_max=40960 \
net.ipv4.tcp_rmem='4096 87380 16777216' \
net.ipv4.tcp_wmem='4096 65536 16777216'
}

performance()
{
echo "Configuring the system cores into performance mode ..." 
for CPUFREQ in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
[ -f $CPUFREQ ] || continue
echo -n performance > $CPUFREQ
done
}

nvme()
{

echo "Configuring the NVMe Settings ..." 
echo 1000 > /proc/sys/vm/watermark_scale_factor
echo 0 > /proc/sys/vm/zone_reclaim_mode
swapoff --all
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
touch /var/lock/subsys/local
echo none > /sys/block/nvme1n1/queue/scheduler
echo none > /sys/block/nvme2n1/queue/scheduler
echo none > /sys/block/nvme3n1/queue/scheduler
echo none > /sys/block/nvme4n1/queue/scheduler 
echo 0 > /sys/class/block/nvme1n1/queue/rotational
echo 0 > /sys/class/block/nvme2n1/queue/rotational
echo 0 > /sys/class/block/nvme3n1/queue/rotational
echo 0 > /sys/class/block/nvme4n1/queue/rotational
echo 8 > /sys/class/block/nvme1n1/queue/read_ahead_kb
echo 8 > /sys/class/block/nvme2n1/queue/read_ahead_kb
echo 8 > /sys/class/block/nvme3n1/queue/read_ahead_kb
echo 8 > /sys/class/block/nvme4n1/queue/read_ahead_kb
}

serverrun()
{    
	cd /root/cass2
    python3 server_parallel.py 
}


db()
{
echo "Restoring the db ..." 
rm -rf /mnt/nvme*/db
cd /mnt/nvme1/orig_db 
find . -type d > dirs.txt
mkdir /mnt/nvme1/db
cp /mnt/nvme1/orig_db/dirs.txt /mnt/nvme1/db
cd /mnt/nvme1/db
xargs mkdir -p < dirs.txt
cp -r /mnt/nvme1/db /mnt/nvme2/.
cp -r /mnt/nvme1/db /mnt/nvme3/.
cp -r /mnt/nvme1/db /mnt/nvme4/.
echo "nvme1"
cd /mnt/nvme1/db
cp -r /mnt/nvme1/orig_db/system* /mnt/nvme1/db/.
cp -r /mnt/nvme1/orig_db/commitlog/ /mnt/nvme1/db/.
cd /mnt/nvme1/db/stresscql/insanitytest-*/
ln -s -b /mnt/nvme1/orig_db/stresscql/insanitytest-*/n* .
echo "nvme2"
cd /mnt/nvme2/db
cp -r /mnt/nvme2/orig_db/system* /mnt/nvme2/db/.
cp -r /mnt/nvme2/orig_db/commitlog/ /mnt/nvme2/db/.
cd /mnt/nvme2/db/stresscql/insanitytest-*/
ln -s -b /mnt/nvme2/orig_db/stresscql/insanitytest-*/n* .
echo "nvme3"
cd /mnt/nvme3/db
cp -r /mnt/nvme3/orig_db/system* /mnt/nvme3/db/.
cp -r /mnt/nvme3/orig_db/commitlog/ /mnt/nvme3/db/.
cd /mnt/nvme3/db/stresscql/insanitytest-*/
ln -s -b /mnt/nvme3/orig_db/stresscql/insanitytest-*/n* .
echo "nvme4"
cd /mnt/nvme4/db
cp -r /mnt/nvme4/orig_db/system* /mnt/nvme4/db/.
cp -r /mnt/nvme4/orig_db/commitlog/ /mnt/nvme4/db/.
cd /mnt/nvme4/db/stresscql/insanitytest-*/
ln -s -b /mnt/nvme4/orig_db/stresscql/insanitytest-*/n* .
}

cassdb()
{
echo "Restoring the cassdb ..." 
rm -rf /mnt/nvme*/db
cd /mnt/nvme1/orig_db
find . -type d > dirs.txt
mkdir /mnt/nvme1/db
cp /mnt/nvme1/orig_db/dirs.txt /mnt/nvme1/db
cd /mnt/nvme1/db
xargs mkdir -p < dirs.txt


cp -r /mnt/nvme1/db* /mnt/nvme3/.
cp -r /mnt/nvme1/db* /mnt/nvme4/.
cp -r /mnt/nvme1/db* /mnt/nvme2/.


echo "nvme3_db"
cd /mnt/nvme3/db
cp -r /mnt/nvme3/orig_db/data/system* /mnt/nvme3/db/data/.
cp -r /mnt/nvme3/orig_db/commitlog/ /mnt/nvme3/db/.
cd /mnt/nvme3/db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/
ln -s -b /mnt/nvme3/orig_db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/n* .
#sleep 1

echo "nvme2_db"
cd /mnt/nvme2/db
cp -r /mnt/nvme2/orig_db/data/system* /mnt/nvme2/db/data/.
cp -r /mnt/nvme2/orig_db/commitlog/ /mnt/nvme2/db/.
cd /mnt/nvme2/db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/
ln -s -b /mnt/nvme2/orig_db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/n* .
#sleep 1

echo "nvme1_db"
cd /mnt/nvme1/db
cp -r /mnt/nvme1/orig_db/data/system* /mnt/nvme1/db/data/.
cp -r /mnt/nvme1/orig_db/commitlog/ /mnt/nvme1/db/.
cd /mnt/nvme1/db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/
ln -s -b /mnt/nvme1/orig_db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/n* .
#sleep 1

echo "nvme4_db"
cd /mnt/nvme4/db
cp -r /mnt/nvme4/orig_db/data/system* /mnt/nvme4/db/data/.
cp -r /mnt/nvme4/orig_db/commitlog/ /mnt/nvme4/db/.
cd /mnt/nvme4/db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/
ln -s -b /mnt/nvme4/orig_db/data/stresscql/insanitytest-004ae810bfbc11ee877d77773cfcec5d/n* .
}

nodetool()
{
echo "Nodetool status ..." 
/root/cass2/apache-cassandra-4.1.3/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.0/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.1/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.2/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.3/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.4/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.5/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.6/bin/nodetool status
/root/cass2/apache-cassandra-4.1.3.7/bin/nodetool status
}


fstrm()
{
    echo "fstrim the nvmes ..." 
    fstrim -v /mnt/nvme1
    fstrim -v /mnt/nvme2
    fstrim -v /mnt/nvme3
    fstrim -v /mnt/nvme4
}

db2()
{

echo "Restoring the db2 ..." 
rm -rf /mnt/nvme*/db2
cd /mnt/nvme1/orig_db 
find . -type d > dirs.txt
mkdir /mnt/nvme1/db2
cp /mnt/nvme1/orig_db/dirs.txt /mnt/nvme1/db2
cd /mnt/nvme1/db2
xargs mkdir -p < dirs.txt
cp -r /mnt/nvme1/db2 /mnt/nvme2/.
cp -r /mnt/nvme1/db2 /mnt/nvme3/.
cp -r /mnt/nvme1/db2 /mnt/nvme4/.
echo "nvme1"
cd /mnt/nvme1/db2
cp -r /mnt/nvme1/orig_db/system* /mnt/nvme1/db2/.
cp -r /mnt/nvme1/orig_db/commitlog/ /mnt/nvme1/db2/.
cd /mnt/nvme1/db2/stresscql/insanitytest-*/
ln -s -b /mnt/nvme1/orig_db/stresscql/insanitytest-*/n* .
echo "nvme2"
cd /mnt/nvme2/db2
cp -r /mnt/nvme2/orig_db/system* /mnt/nvme2/db2/.
cp -r /mnt/nvme2/orig_db/commitlog/ /mnt/nvme2/db2/.
cd /mnt/nvme2/db2/stresscql/insanitytest-*/
ln -s -b /mnt/nvme2/orig_db/stresscql/insanitytest-*/n* .
echo "nvme3"
cd /mnt/nvme3/db2
cp -r /mnt/nvme3/orig_db/system* /mnt/nvme3/db2/.
cp -r /mnt/nvme3/orig_db/commitlog/ /mnt/nvme3/db2/.
cd /mnt/nvme3/db2/stresscql/insanitytest-*/
ln -s -b /mnt/nvme3/orig_db/stresscql/insanitytest-*/n* .

echo "nvme4"
cd /mnt/nvme4/db2
cp -r /mnt/nvme4/orig_db/system* /mnt/nvme4/db2/.
cp -r /mnt/nvme4/orig_db/commitlog/ /mnt/nvme4/db2/.
cd /mnt/nvme4/db2/stresscql/insanitytest-*/
ln -s -b /mnt/nvme4/orig_db/stresscql/insanitytest-*/n* .
}


fil()
{
sysctl -w net.ipv4.conf.all.rp_filter=2
}

cache()
{
echo "******* now clear the caches*********"
echo "clear caches"
sync; echo 3 > /proc/sys/vm/drop_caches
}

print_db()
{
du -sh /mnt/nvme*/db*
du -sh /mnt/nvme*/orig_db*
}


clean()
{
rm -rf __mpp*
mv cassandra_*.csv output/
mv emon_*.xlsx emon/
mv *.dat emon/

}
run()
{
clean
kill
cache
dhclient
mnt
fstrm
network
nvme
ip2
performance
cassdb
cache
print_db
serverrun
}

$1
echo "Give arguments : ip1,ip2,mnt,network,perf,nvme,kill,db,db2,nodetool,fill,set"
