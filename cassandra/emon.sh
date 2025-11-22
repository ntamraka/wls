
source /opt/intel/sep/sep_vars.sh
/opt/intel/sep/sepdk/src/insmod-sep

echo "emon collection started"
wd=$(pwd)
date="$(date +"%d_%H_%M")"
#mkdir -p ${2}  
name=emon_${2}
timeout $1 emon -collect-edp > ${name}.dat
 
/usr/bin/python3.9 /opt/intel/sep/config/edp/pyedp/edp.py -i ${name}.dat -m /opt/intel/sep/config/edp/sierraforest_server_2s_private.xml -f /opt/intel/sep/config/edp/chart_format_sierraforest_server_private.txt -o ${name}.xlsx --socket-view 
