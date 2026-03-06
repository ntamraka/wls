
#!/bin/bash

# Configuration
INTERFACE="ens3np0"


./core_manage.sh offline 0 223
./core_manage.sh online 0 55
ethtool -L $INTERFACE combined 16
./server_script.sh 56
./irq_dmr.sh 0 16
./scaling.sh ping "cbb_scaling_Core_0-55_CCB0_irq_combined_14_local_pipe_1_size_64" 56 

./core_manage.sh offline 0 223
./core_manage.sh online 0 111
ethtool -L $INTERFACE combined 32
./server_script.sh 112
./irq_dmr.sh '0 1' 16
./scaling.sh ping "cbb_scaling_Core_0-111_CCB1_irq_combined_28_local_pipe_1_size_64" 112 

./core_manage.sh offline 0 223
./core_manage.sh online 0 167
ethtool -L $INTERFACE combined 48
./server_script.sh 168
./irq_dmr.sh '0 1 2' 16
./scaling.sh ping "cbb_scaling_Core_0-167_CCB2_irq_combined_42_local_pipe_1_size_64" 168 

./core_manage.sh offline 0 223
./core_manage.sh online 0 224
ethtool -L $INTERFACE combined 64
./server_script.sh 224
./irq_dmr.sh '0 1 2 3' 16
./scaling.sh ping "cbb_scaling_Core_0-223_CCB3_irq_combined_56_local_pipe_1_size_64" 224 