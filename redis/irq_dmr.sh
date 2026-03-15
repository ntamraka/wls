PCI_DEVICE="b1:00.0"
NIC_NAME="ens3np0"

tune_irq_affinity() {
    local segments="$1"
    local step_size="$2"

    echo "=============================================="
    echo " IRQ Affinity Tuning Started"
    echo " PCI Device : $PCI_DEVICE"
    echo " NIC        : $NIC_NAME"
    echo " Target     : UPTP 224 Core Layout"
    echo " Policy     : $step_size CPUs per segment"
    echo " Segments   : $segments"
    echo "=============================================="

    ############################################
    # Collect only TxRx IRQs
    ############################################

    IRQ_NUMS=$(grep "$NIC_NAME" /proc/interrupts \
        | grep TxRx \
        | cut -d: -f1 | tr -d ' ')

    if [[ -z "$IRQ_NUMS" ]]; then
        echo "[WARNING] No TxRx IRQs found for NIC $NIC_NAME"
        return 1
    fi

    ############################################
    # Build CPU layout
    ############################################

    CPU_LIST=()

    echo ""
    echo "Building CPU Segments:"
    echo "----------------------------------------------"

    read -ra segs <<< "$segments"

    for seg in "${segs[@]}"
    do
        BASE=$((seg * 56))
        START=$BASE
        END=$((BASE + step_size - 1))

        echo " Segment $seg → CPUs ${START}-${END}"

        for ((i=0;i<step_size;i++))
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

tune_irq_affinity "$1" "${2:-14}"