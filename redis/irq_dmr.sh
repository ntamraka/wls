PCI_DEVICE="b1:00.0"

#PCI_DEVICE="2a:00.0"

tune_irq_affinity() {

    echo "=============================================="
    echo " IRQ Affinity Tuning Started"
    echo " PCI Device : $PCI_DEVICE"
    echo " Target     : UPTP 224 Core Layout"
    echo " Policy     : 14 CPUs per segment (4 segments)"
    echo "=============================================="

    IRQ_NUMS=$(grep "$PCI_DEVICE" /proc/interrupts 2>/dev/null \
        | cut -d: -f1 | tr -d ' ' || true)

    if [[ -z "$IRQ_NUMS" ]]; then
        echo "[WARNING] No IRQs found for PCI device $PCI_DEVICE"
        return 1
    fi

    ############################################
    # Build CPU layout
    ############################################

    CPU_LIST=()

    echo ""
    echo "Building CPU Segments:"
    echo "----------------------------------------------"

    for seg in 2 
    do
        BASE=$((seg * 56))
        START=$BASE
        END=$((BASE + 13))

        echo " Segment $seg → CPUs ${START}-${END}"

        for ((i=0;i<14;i++))
        do
            CPU_LIST+=($((BASE + i)))
        done
    done

    echo "----------------------------------------------"
    echo "Total CPUs used for IRQ placement : ${#CPU_LIST[@]}"
    echo ""

    ############################################
    # Apply IRQ Mapping
    ############################################

    echo "Applying IRQ → CPU affinity"
    echo "----------------------------------------------"

    i=0
    TOTAL_CPUS=${#CPU_LIST[@]}

    for irq in $IRQ_NUMS
    do
        cpu=${CPU_LIST[$((i % TOTAL_CPUS))]}

        printf " Mapping IRQ %-5s --> CPU %-5s\n" "$irq" "$cpu"

        echo "$cpu" > /proc/irq/$irq/smp_affinity_list

        ((i++))
    done

    echo "----------------------------------------------"
    echo "Total IRQs tuned : $i"
    echo ""
    echo "✅ IRQ affinity tuning completed successfully"
    echo "=============================================="
}
tune_irq_affinity
