import paramiko
import os
import argparse
import concurrent.futures
import time

# Function to create a script file locally
def create_script_file(script_content, filename):
    with open(filename, 'w') as file:
        file.write(script_content)

# Function to transfer a file to a remote server
def transfer_file_to_remote(hostname, port, username, password, local_file, remote_file):
    try:
        # Create an SSH client
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(hostname, port=port, username=username, password=password)

        # Use SCP to transfer the file
        scp = paramiko.SFTPClient.from_transport(client.get_transport())
        scp.put(local_file, remote_file)
        scp.close()
    except Exception as e:
        print(f"An error occurred during file transfer: {e}")
    finally:
        client.close()

# Function to run a remote command
def run_remote_command(hostname, port, username, password, command):
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(hostname, port=port, username=username, password=password)
        stdin, stdout, stderr = client.exec_command(command)
        output = stdout.read().decode()
        error = stderr.read().decode()
        print(f"Remote Command Output for {hostname}:")
        print(output)
        if error:
            print(f"Remote Command Error for {hostname}:")
            print(error)
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        client.close()

# Set up argument parsing
def parse_args():
    parser = argparse.ArgumentParser(description="Run remote and local benchmark commands.")
    parser.add_argument('-c', '--core', type=int, required=True, help="Number of cores")
    parser.add_argument('-s', '--size', type=int, required=True, help="Number of size")
    parser.add_argument('-p', '--pipeline', type=int, required=True, help="Number of pipeline")
    return parser.parse_args()

# Main function
def main():
    args = parse_args()
    port = 22
    username = 'root'
    #password = os.getenv('SSH_PASSWORD', 'Password123!23')
    password = os.getenv('SSH_PASSWORD', 'dcso@123')
    core = args.core
    size = args.size
    pipeline = args.pipeline

    # Script content
    script_content = """
    #!/bin/bash

pcpu=$1
x=0
REDIS_SERVER="192.168.100.1"
LOG_DIR="/root/memtier_benchmark/log_${1}"

# Cleanup previous runs
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
killall -9 memtier_benchmark 2>/dev/null

# Array to store PIDs
declare -a pids

for j in $(seq 1 2 ${pcpu}); do
    portp=$(($4 + j))
    
    taskset -c $x memtier_benchmark \
        -s $REDIS_SERVER -p ${portp} \
        --threads=1 --test-time 80 \
        --clients=100 --data-size=$2 \
        --ratio=1:0 --pipeline=$3 \
        --out-file=${LOG_DIR}/log_${portp} &
    
    pids[$x]=$!  # Store PID
    let x+=1
done

# Wait for all processes to complete
for pid in ${pids[*]}; do
    wait $pid
done

echo "Benchmark completed. Results in $LOG_DIR"
"""
    

    script2_content = """#!/bin/bash
    grep -r "Total" $1 | awk '{sum += $2; print $2; next} END {print "total number of IOPS for",NR, " Instance ", sum/NR }'

    """


    # Create the script file locally
    local_script_file = 'remote_script.sh'
    create_script_file(script_content, local_script_file)
    local_script_file2 = 'output_script.sh'
    create_script_file(script2_content, local_script_file2)

    # Define remote script path
    remote_script_file = '/root/memtier_benchmark/remote_script.sh'
    remote_script_file2 = '/root/memtier_benchmark/output_script.sh'

    # Hostnames to run the script on
    hostnames = [ '192.168.100.2',  '192.168.100.3']
    #hostnames = ['10.140.133.17']
    startports = ['16000', '16001']
    #startports = ['16000']
    #core=core//2

    # Use ThreadPoolExecutor for I/O-bound tasks
    with concurrent.futures.ThreadPoolExecutor() as executor:
        # Transfer and execute the script on each remote host
        for i in range(len(hostnames)):
            executor.submit(transfer_file_to_remote, hostnames[i], port, username, password, local_script_file, remote_script_file)
            executor.submit(transfer_file_to_remote, hostnames[i], port, username, password, local_script_file2, remote_script_file2)
            time.sleep(2)
            executor.submit(run_remote_command, hostnames[i], port, username, password, f'bash {remote_script_file} {core} {size} {pipeline} {startports[i]}')
           
    time.sleep(10)
    for hostname in hostnames:
        run_remote_command(hostname, port, username, password, f'bash /root/memtier_benchmark/output_script.sh /root/memtier_benchmark/log_{core}')
    
if __name__ == "__main__":
    main()
