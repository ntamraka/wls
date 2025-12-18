#!/bin/bash

config=$1

function run_emon()

{


time=60
log_prefix=$1
sleep_time=$2
log="${log_prefix}_${config}"
echo  "Running with Emon ... emon will start after $sleep_time seconds"

#dt=`date '+%d%m%Y%H%M%S'`
cmd="sleep $time"
emon_cmd="tmc -c '$cmd' -u -i $log -a $log -x gauritsh -n"

sleep $sleep_time

echo $emon_cmd
eval $emon_cmd


}




function parse_mlc_logs_individual()

{

traffic=$1
final_summary_file=$2

echo "**********Parsing $traffic data ***************"

if [ "${traffic}" = "idle_latency_cmd" ]
then
Latency=`cat $mlc_log_file | tail -n 2 | head -n 1 | awk '{print$9}'`
Throughput="NA"
else
Latency=`cat $mlc_log_file | tail -n 1 | awk '{print $2}'`
Throughput=`cat $mlc_log_file | tail -n 1 | awk '{print $3}'`
fi

echo "Traffic Type          Latency          Throughput"
echo "${traffic}          ${Latency}           ${Throughput}" >> $final_summary_file
echo " "

}


function run_mlc_individual()
{

dt=`date '+%m%d%Y%H%M%S'`

mlc_path="/home/gaurit/mlc"
mlc_logs_dir="${mlc_path}/mlc_logs"


mlc_binary="${mlc_path}/mlc_internal"     #inside VM
cpuset="0-50"
numanode=1
latency_core=51


#read_only_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -R && wait"
#3_1_rw_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W3 && wait"
#2_1_rw_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W2 && wait"
#1_1_rw_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W5 && wait"
#2_1_rnt_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W7 && wait"
#1_1_rnt_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W8 && wait"
#0_1_rnt_cmd="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t30 -K1 -W6 && wait"
#idle_latency_cmd="$mlc_binary --idle_latency -b700000 -t10 -c0 -j$numanode -e -r -l128"



log_file="mlc_baremetal_${config}_${dt}"


if [ -d "$PWD/mlc_logs" ]; then
        echo " "
        echo "mlc_logs directory found  .. "
else
        echo " "
        echo "creating mlc_logs directory..."
        `mkdir mlc_logs`
fi


final_summary_file="$PWD/mlc_logs/${log_file}_summary.log"
touch $final_summary_file
echo "Traffic Type          Latency          Throughput" >> $final_summary_file

declare -A cmds
mlc_time=180

keys=("read_only_cmd" "3_1_rw_cmd" "2_1_rw_cmd" "1_1_rw_cmd" "2_1_rnt_cmd" "1_1_rnt_cmd" "0_1_rnt_cmd" "idle_latency_cmd")

cmds=( ["read_only_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -R && wait" ["3_1_rw_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W3 && wait" ["2_1_rw_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W2 && wait" ["1_1_rw_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W5 && wait" ["2_1_rnt_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W7 && wait" ["1_1_rnt_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W8 && wait" ["0_1_rnt_cmd"]="$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -t$mlc_time -K1 -W6 && wait" ["idle_latency_cmd"]="$mlc_binary --idle_latency -b700000 -t$mlc_time -c0 -j$numanode -e -r -l128" )


for cmd in "${keys[@]}";
do

log_file_individual="${log_file}_${cmd}.log"
run_cmd="(${cmds[$cmd]}) 2>&1 | tee ${mlc_logs_dir}/${log_file_individual} && wait"
#copy_logs_cmd="scp -r root@$ip:$mlc_logs_dir/${log_file_individual} $PWD/mlc_logs"

echo $run_cmd

#Starting Emon in the background
run_emon "${log_file}_${cmd}" 90 &


eval $run_cmd && wait

mlc_log_file="$PWD/mlc_logs/${log_file_individual}"

parse_mlc_logs_individual $cmd $final_summary_file && wait

sudo killall emon && wait
sudo killall tmc && wait

sleep 10 && wait

done

echo ""
echo "############## Final MLC Summary ###################"
echo ""
cat $final_summary_file
echo ""

}

run_mlc_individual && wait

