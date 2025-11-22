
#!/bin/bash
# -------------------------------------------------------------------
# NIC + CPU tuning for high-core system running Redis/memtier
# - Backup current settings
# - Set all CPUs to performance governor
# - Report RX/TX queue counts
# - Enable RPS/XPS across all CPUs
# - Distribute IRQs dynamically based on PCI device
# - Can revert changes using backup
# -------------------------------------------------------------------

BACKUP_DIR="/tmp/sys_tuning_backup"
mkdir -p "$BACKUP_DIR"

echo "==== 0. Backup current CPU governors ===="
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    CPU_NAME=$(basename $(dirname $cpu))
    CURRENT=$(cat "$cpu")
    echo "$CURRENT" > "$BACKUP_DIR/${CPU_NAME}_governor.bak"
done
echo "---- CPU governors backed up ----"
echo

echo "==== 1. Set CPU frequency governor to 'performance' ===="
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    CPU_NAME=$(basename $(dirname $cpu))
    echo "  -> Setting $CPU_NAME to performance"
    echo performance > "$cpu"
done
echo "---- CPU governors set to performance ----"
echo

echo "==== 2. Check NIC RX/TX queues ===="
RX_Q=$(ls -d /sys/class/net/ens6np0/queues/rx-* | wc -l)
TX_Q=$(ls -d /sys/class/net/ens6np0/queues/tx-* | wc -l)
echo "  -> ens6np0 RX queues: $RX_Q"
echo "  -> ens6np0 TX queues: $TX_Q"
echo

#MASK="00000000,0f0f0f0f,0f0f0f0f,00000000,0f0f0f0f,0f0f0f0f,00000000,0f0f0f0f,0f0f0f0f"
#MASK="00000000,00000000,00000000,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f"
#MASK="00000000,00000000,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f"
#MASK="0000ffff,0000fff,0000ffff,0000fff,0000ffff,0000fff,0000ffff,0000fff,0000ffff"
#MASK="00000000,ffffffff,00000000,ffffffff,00000000,ffffffff,00000000,ffffffff,00000000"
#MASK="ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="00000000,00000000,00000000,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
MASK="ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000"

echo "==== 3. Backup & enable RPS on all RX queues ===="
for q in /sys/class/net/ens6np0/queues/rx-*; 
do
    QUEUE=$(basename $q)
    cp "$q/rps_cpus" "$BACKUP_DIR/${QUEUE}_rps.bak"
done


for q in /sys/class/net/ens6np0/queues/rx-*; 
do
    echo "  -> Applying full CPU mask to $(basename $q)/rps_cpus"
    echo "$MASK" > "$q/rps_cpus"
done
echo "---- RPS enabled ----"
echo

echo "==== 4. Backup & enable XPS on all TX queues ===="
for q in /sys/class/net/ens6np0/queues/tx-*; 
do
    QUEUE=$(basename $q)
    cp "$q/xps_cpus" "$BACKUP_DIR/${QUEUE}_xps.bak"
done

for q in /sys/class/net/ens6np0/queues/tx-*;
do
    echo "  -> Applying full CPU mask to $(basename $q)/xps_cpus"
    echo "$MASK" > "$q/xps_cpus"
done
echo "---- XPS enabled ----"
echo

echo "==== 5. Backup IRQ affinities for PCI device 34:00.0 ===="
IRQ_NUMS=$(grep "34:00.0" /proc/interrupts | cut -d: -f1 | tr -d ' ')
echo "  -> Found IRQs: $IRQ_NUMS"
for irq in $IRQ_NUMS; 
do  
echo $irq
    cat "/proc/irq/${irq}/smp_affinity_list" > "$BACKUP_DIR/irq_${irq}.bak"
done
echo "---- IRQ affinities backed up ----"
echo

echo "==== 6. Distribute IRQs across 4 CPUs each ===="
start_cpu=0
total_cpus=$(nproc)
for irq in $IRQ_NUMS; do
    c0=$((start_cpu % total_cpus))
    c1=$(((start_cpu + 96) % total_cpus))
    c2=$(((start_cpu + 192) % total_cpus))
    #echo "$c0,$c1,$c2" > "/proc/irq/${irq}/smp_affinity_list"
    #c3=$(((start_cpu + 192) % total_cpus))
    echo "  -> IRQ $irq -> CPUs $c0,$c1,$c2"
    #echo "$c0" > "/proc/irq/${irq}/smp_affinity_list"
    echo "$c0,$c1,$c2" > "/proc/irq/${irq}/smp_affinity_list"
    start_cpu=$((start_cpu + 1))
done
echo "---- IRQ affinities set ----"
echo

echo "==== All tuning complete ===="
echo "Backup of original settings saved in $BACKUP_DIR"
echo

#echo "==== Revert instructions ===="
#echo "To revert changes, run:"
#echo "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do"
#echo "    CPU_NAME=\$(basename \$(dirname \$cpu))"
#echo "    cat $BACKUP_DIR/\${CPU_NAME}_governor.bak > \$cpu"
#echo "done"
#echo "for q in /sys/class/net/ens6np0/queues/rx-*; do"
#echo "    QUEUE=\$(basename \$q); cat $BACKUP_DIR/\${QUEUE}_rps.bak > \$q/rps_cpus"
#echo "done"
#echo "for q in /sys/class/net/ens6np0/queues/tx-*; do"
#echo "    QUEUE=\$(basename \$q); cat $BACKUP_DIR/\${QUEUE}_xps.bak > \$q/xps_cpus"
#echo "done"
#echo "for irq in $IRQ_NUMS; do cat $BACKUP_DIR/irq_\${irq}.bak > /proc/irq/\${irq}/smp_affinity_list; done"




