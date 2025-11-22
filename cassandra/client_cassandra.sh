echo "Execution started"

for i in 1 
do
for threads in  $2
do 
    for time in 10 #180 240 300
    do 
        log=${1}_80R-20W_${time}m_${threads}T_${i}
        python3 client_parallel.py -n $log -T $time -t $threads 
        sleep 20
    done
  done 
done
