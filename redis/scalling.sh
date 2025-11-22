
# Loop from 1 to 240 cores

name=$1
#name="Clientt6_Thread10_Con20_Core-Scalling_run_irq0"

#for pipe in 1 4 8 16 32 48 64 128 264
for pipe in 1
do
#for core in 4 8 16 32 48 64 80	96 112 128 144 160 176 192 208 224 240
#for core in $(seq 16 16 144); 
for core in 288
do 
for size in 64
do
    #killall sar
    #killall vmstat
    #killall iostat 
    #killall emon
    #./core_manage.sh offline 16 288
    #./core_manage.sh online 16 $core
    #./tuning.sh 
    #sleep 10
    echo "python3 benchmarkAliPing1.py -p ${pipe} -c ${core} -s ${size} "
   #python3 benchmarkAliPing1.py -p ${pipe} -c ${core} -s ${size} 2>&1 | tee Redis_pipe-${pipe}_size-${size}_core-${core}_ping_${name}.txt
    python3 /root/tmc/tmc.py -u -Z metrics2  -n -x ntamraka -d /root/tmc/redis -G Redis_study_scale -r 30 -t 60 -i redis -a pipe-${pipe}_size-${size}_core-${core}_ping__${name} -c "python3 benchmarkAliPing1.py -p ${pipe} -c ${core} -s ${size} 2>&1 | tee Redis_pipe-${pipe}_size-${size}_core-${core}_ping__${name}.txt" 
    #sleep 20
done
done
done
./output2.sh $name
echo "Benchmarking completed!"


#python3 /root/tmc/tmc.py -u -n -x ntamraka -d /root/tmc/redis -G redis -t 80 -i redis -a redis_${core} -c ""

#./core_manage.sh online $core 240
#4 8 16 32 48 64 80	96 112 128 144 160 176

