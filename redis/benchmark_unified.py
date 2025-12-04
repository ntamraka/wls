#!/usr/bin/env python3
"""
Unified Redis Benchmark Script
Supports multiple operation types: ping, read, write, readwrite
"""

import paramiko
import os
import argparse
import concurrent.futures
import time
import sys
from datetime import datetime
import re

# Configuration for different benchmark types
BENCHMARK_CONFIGS = {
    'ping': {
        'hostnames': ['192.168.200.2', '192.168.200.3', '192.168.200.4', 
                      '192.168.200.5', '192.168.200.6', '192.168.200.7'],
        'startports': ['16000', '16001', '16002', '16003', '16004', '16005'],
        'redis_server': '192.168.200.1',
        'test_time': 100,
        'seq_step': 6,
        'command': 'ping',
        'ratio': None,
    },
    'read': {
        'hostnames': ['192.168.100.2', '192.168.100.3'],
        'startports': ['16000', '16001'],
        'redis_server': '192.168.100.1',
        'test_time': 80,
        'seq_step': 2,
        'command': None,
        'ratio': '0:1',  # 100% read
    },
    'write': {
        'hostnames': ['192.168.100.2', '192.168.100.3'],
        'startports': ['16000', '16001'],
        'redis_server': '192.168.100.1',
        'test_time': 80,
        'seq_step': 2,
        'command': None,
        'ratio': '1:0',  # 100% write
    },
    'readwrite': {
        'hostnames': ['192.168.100.2', '192.168.100.3'],
        'startports': ['16000', '16001'],
        'redis_server': '192.168.100.1',
        'test_time': 80,
        'seq_step': 2,
        'command': None,
        'ratio': '1:1',  # 50/50 read/write
    }
}

# Global statistics tracking
benchmark_stats = {
    'start_time': None,
    'end_time': None,
    'transfer_success': 0,
    'transfer_failed': 0,
    'benchmark_success': 0,
    'benchmark_failed': 0,
    'results': []
}

# Color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def log_info(message):
    """Print info message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{Colors.OKBLUE}[{timestamp}] [INFO]{Colors.ENDC} {message}")

def log_success(message):
    """Print success message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{Colors.OKGREEN}[{timestamp}] [SUCCESS]{Colors.ENDC} {message}")

def log_warning(message):
    """Print warning message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{Colors.WARNING}[{timestamp}] [WARNING]{Colors.ENDC} {message}")

def log_error(message):
    """Print error message"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{Colors.FAIL}[{timestamp}] [ERROR]{Colors.ENDC} {message}")

def print_separator(char='=', length=80):
    """Print a separator line"""
    print(char * length)

def print_header(title):
    """Print a formatted header"""
    print(f"\n{Colors.BOLD}{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}{title.center(80)}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'='*80}{Colors.ENDC}\n")

def create_script_file(script_content, filename):
    """Create a script file locally"""
    try:
        with open(filename, 'w') as file:
            file.write(script_content)
        log_success(f"Created local script: {filename}")
        return True
    except Exception as e:
        log_error(f"Failed to create script {filename}: {e}")
        return False

def transfer_file_to_remote(hostname, port, username, password, local_file, remote_file):
    """Transfer a file to a remote server via SCP"""
    try:
        log_info(f"Transferring {local_file} to {hostname}...")
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(hostname, port=port, username=username, password=password, timeout=10)

        scp = paramiko.SFTPClient.from_transport(client.get_transport())
        scp.put(local_file, remote_file)
        scp.close()
        log_success(f"Transferred to {hostname}:{remote_file}")
        benchmark_stats['transfer_success'] += 1
        return True
    except Exception as e:
        log_error(f"Failed to transfer to {hostname}: {e}")
        benchmark_stats['transfer_failed'] += 1
        return False
    finally:
        client.close()

def run_remote_command(hostname, port, username, password, command, collect_metrics=False):
    """Run a remote command via SSH"""
    try:
        log_info(f"Executing command on {hostname}...")
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(hostname, port=port, username=username, password=password, timeout=10)
        
        stdin, stdout, stderr = client.exec_command(command)
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        if collect_metrics:
            # Parse metrics from output
            metrics = parse_benchmark_output(output, hostname)
            if metrics:
                benchmark_stats['results'].append(metrics)
        
        print(f"\n{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}Remote Output from {hostname}:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}{'─'*80}{Colors.ENDC}")
        if output.strip():
            print(output)
        if error.strip():
            log_warning(f"Stderr from {hostname}:")
            print(error)
        print(f"{Colors.OKCYAN}{'─'*80}{Colors.ENDC}\n")
        
        benchmark_stats['benchmark_success'] += 1
        return True
    except Exception as e:
        log_error(f"Failed to execute on {hostname}: {e}")
        benchmark_stats['benchmark_failed'] += 1
        return False
    finally:
        client.close()

def parse_benchmark_output(output, hostname):
    """Parse benchmark metrics from output"""
    try:
        metrics = {'hostname': hostname}
        
        # Extract IOPS/throughput
        iops_match = re.search(r'total number of IOPS.*?(\d+\.?\d*)', output)
        if iops_match:
            metrics['iops'] = float(iops_match.group(1))
        
        # Extract instance count
        instance_match = re.search(r'for\s+(\d+)\s+Instance', output)
        if instance_match:
            metrics['instances'] = int(instance_match.group(1))
        
        return metrics if metrics.get('iops') else None
    except Exception as e:
        log_warning(f"Failed to parse metrics from {hostname}: {e}")
        return None

def generate_benchmark_script(operation, config, core, size, pipeline):
    """Generate the benchmark script based on operation type"""
    
    # Unified log directory for all operations
    log_dir_base = "/root/wls/redis/memtier_benchmark"
    
    if operation == 'ping':
        # PING command benchmark
        script_content = f"""#!/bin/bash

pcpu=$1
x=0
REDIS_SERVER="{config['redis_server']}"
LOG_DIR="{log_dir_base}/log_${{1}}"

# Cleanup previous runs
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
killall -9 memtier_benchmark 2>/dev/null

# Array to store PIDs
declare -a pids

for j in $(seq 1 {config['seq_step']} ${{pcpu}}); do
    portp=$(($4 + j))
    
    taskset -c $x memtier_benchmark \\
        -s $REDIS_SERVER -p ${{portp}} \\
        --threads=1 --test-time {config['test_time']} --pipeline=$3 \\
        --hide-histogram --command='ping' \\
        --clients=100 --data-size=64 \\
        --out-file=${{LOG_DIR}}/log_${{portp}} &
    
    pids[$x]=$!
    let x+=1
done

# Wait for all processes to complete
for pid in ${{pids[*]}}; do
    wait $pid
done

echo "Benchmark completed. Results in $LOG_DIR"
"""
    else:
        # GET/SET benchmarks
        script_content = f"""#!/bin/bash

pcpu=$1
x=0
REDIS_SERVER="{config['redis_server']}"
LOG_DIR="{log_dir_base}/log_${{1}}"

# Cleanup previous runs
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
killall -9 memtier_benchmark 2>/dev/null

# Array to store PIDs
declare -a pids

for j in $(seq 1 {config['seq_step']} ${{pcpu}}); do
    portp=$(($4 + j))
    
    taskset -c $x memtier_benchmark \\
        -s $REDIS_SERVER -p ${{portp}} \\
        --threads=1 --test-time {config['test_time']} \\
        --clients=100 --data-size=$2 \\
        --ratio={config['ratio']} --pipeline=$3 \\
        --out-file=${{LOG_DIR}}/log_${{portp}} &
    
    pids[$x]=$!
    let x+=1
done

# Wait for all processes to complete
for pid in ${{pids[*]}}; do
    wait $pid
done

echo "Benchmark completed. Results in $LOG_DIR"
"""
    
    return script_content

def generate_output_script():
    """Generate the output aggregation script"""
    return """#!/bin/bash
grep -r "Total" $1 | awk '{sum += $2; print $2; next} END {print "total number of IOPS for",NR, " Instance ", sum/NR }'
"""

def print_summary(args, config):
    """Print final benchmark summary"""
    print_header("BENCHMARK SUMMARY")
    
    duration = (benchmark_stats['end_time'] - benchmark_stats['start_time']).total_seconds()
    
    # Configuration summary
    print(f"{Colors.BOLD}Configuration:{Colors.ENDC}")
    print(f"  Operation Type:    {args.operation.upper()}")
    print(f"  Cores:             {args.core}")
    print(f"  Data Size:         {args.size} bytes")
    print(f"  Pipeline Depth:    {args.pipeline}")
    print(f"  Test Duration:     {config['test_time']}s per client")
    print(f"  Client Servers:    {len(config['hostnames'])}")
    if config['ratio']:
        print(f"  Read/Write Ratio:  {config['ratio']}")
    print()
    
    # Execution summary
    print(f"{Colors.BOLD}Execution Summary:{Colors.ENDC}")
    print(f"  Total Runtime:     {duration:.2f}s")
    print(f"  File Transfers:    {Colors.OKGREEN}{benchmark_stats['transfer_success']} succeeded{Colors.ENDC}, "
          f"{Colors.FAIL}{benchmark_stats['transfer_failed']} failed{Colors.ENDC}")
    print(f"  Benchmark Runs:    {Colors.OKGREEN}{benchmark_stats['benchmark_success']} succeeded{Colors.ENDC}, "
          f"{Colors.FAIL}{benchmark_stats['benchmark_failed']} failed{Colors.ENDC}")
    print()
    
    # Performance summary
    if benchmark_stats['results']:
        print(f"{Colors.BOLD}Performance Results:{Colors.ENDC}")
        total_iops = 0
        for result in benchmark_stats['results']:
            if 'iops' in result:
                print(f"  {result['hostname']:<20} {result.get('iops', 0):>15,.2f} ops/sec "
                      f"({result.get('instances', 'N/A')} instances)")
                total_iops += result['iops']
        
        if total_iops > 0:
            print(f"\n  {Colors.BOLD}{Colors.OKGREEN}Total Throughput:   {total_iops:>15,.2f} ops/sec{Colors.ENDC}")
            print(f"  {Colors.BOLD}Average per Client: {total_iops/len(benchmark_stats['results']):>15,.2f} ops/sec{Colors.ENDC}")
    else:
        log_warning("No performance metrics collected")
    
    print()
    print_separator('=', 80)
    
    # Status indicator
    if benchmark_stats['transfer_failed'] == 0 and benchmark_stats['benchmark_failed'] == 0:
        log_success("All operations completed successfully!")
    else:
        log_warning("Some operations failed. Check logs above for details.")
    
    print_separator('=', 80)

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Unified Redis Benchmark Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Operation Types:
  ping       - PING latency benchmark (6 clients, 192.168.200.x)
  read       - Read-only benchmark (2 clients, 192.168.100.x)
  write      - Write-only benchmark (2 clients, 192.168.100.x)
  readwrite  - Mixed 50/50 read/write benchmark (2 clients, 192.168.100.x)

Examples:
  %(prog)s -o ping -c 288 -s 64 -p 1
  %(prog)s -o read -c 144 -s 1024 -p 16
  %(prog)s -o write -c 96 -s 512 -p 8
  %(prog)s -o readwrite -c 192 -s 256 -p 4
        """
    )
    parser.add_argument('-o', '--operation', 
                        type=str, 
                        required=True,
                        choices=['ping', 'read', 'write', 'readwrite'],
                        help="Benchmark operation type")
    parser.add_argument('-c', '--core', 
                        type=int, 
                        required=True, 
                        help="Number of cores")
    parser.add_argument('-s', '--size', 
                        type=int, 
                        required=True, 
                        help="Data size in bytes")
    parser.add_argument('-p', '--pipeline', 
                        type=int, 
                        required=True, 
                        help="Pipeline depth")
    parser.add_argument('--username',
                        type=str,
                        default='root',
                        help="SSH username (default: root)")
    parser.add_argument('--port',
                        type=int,
                        default=22,
                        help="SSH port (default: 22)")
    return parser.parse_args()

def main():
    """Main execution function"""
    benchmark_stats['start_time'] = datetime.now()
    
    args = parse_args()
    
    # Get operation configuration
    if args.operation not in BENCHMARK_CONFIGS:
        log_error(f"Unknown operation type '{args.operation}'")
        sys.exit(1)
    
    config = BENCHMARK_CONFIGS[args.operation]
    
    # Get SSH credentials
    port = args.port
    username = args.username
    #password = os.getenv('SSH_PASSWORD', 'dcso@123')
    password = os.getenv('SSH_PASSWORD', 'Password123!23')
    
    if not password:
        log_error("SSH_PASSWORD environment variable not set")
        sys.exit(1)
    
    core = args.core
    size = args.size
    pipeline = args.pipeline
    
    # Print configuration
    print_header("REDIS UNIFIED BENCHMARK")
    
    print(f"{Colors.BOLD}Benchmark Configuration:{Colors.ENDC}")
    print(f"  Operation:         {Colors.OKCYAN}{args.operation.upper()}{Colors.ENDC}")
    print(f"  Cores:             {core}")
    print(f"  Data Size:         {size} bytes")
    print(f"  Pipeline Depth:    {pipeline}")
    print(f"  Test Duration:     {config['test_time']}s")
    print(f"  Client Servers:    {len(config['hostnames'])}")
    print(f"  Redis Server:      {config['redis_server']}")
    if config['ratio']:
        print(f"  Read/Write Ratio:  {config['ratio']}")
    if config['command']:
        print(f"  Command:           {config['command'].upper()}")
    print()
    
    log_info(f"Clients: {', '.join(config['hostnames'])}")
    print()
    
    # Generate scripts
    log_info("Generating benchmark scripts...")
    benchmark_script = generate_benchmark_script(args.operation, config, core, size, pipeline)
    output_script = generate_output_script()
    
    # Create local script files
    local_script_file = 'remote_script.sh'
    local_script_file2 = 'output_script.sh'
    
    if not create_script_file(benchmark_script, local_script_file):
        sys.exit(1)
    if not create_script_file(output_script, local_script_file2):
        sys.exit(1)
    
    # Define remote paths - unified directory for all operations
    remote_dir = '/root/wls/redis/memtier_benchmark'
    
    remote_script_file = f'{remote_dir}/remote_script.sh'
    remote_script_file2 = f'{remote_dir}/output_script.sh'
    
    hostnames = config['hostnames']
    startports = config['startports']
    
    # Phase 1: Transfer scripts
    print_header("PHASE 1: SCRIPT DISTRIBUTION")
    log_info(f"Transferring scripts to {len(hostnames)} client servers...")
    
    transfer_start = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(hostnames)) as executor:
        futures = []
        for hostname in hostnames:
            futures.append(executor.submit(transfer_file_to_remote, hostname, port, username, 
                                          password, local_script_file, remote_script_file))
            futures.append(executor.submit(transfer_file_to_remote, hostname, port, username, 
                                          password, local_script_file2, remote_script_file2))
        
        for future in concurrent.futures.as_completed(futures):
            future.result()
    
    transfer_duration = time.time() - transfer_start
    log_success(f"Script distribution completed in {transfer_duration:.2f}s")
    print()
    
    # Phase 2: Execute benchmarks
    print_header("PHASE 2: BENCHMARK EXECUTION")
    log_info(f"Starting benchmark on {len(hostnames)} clients...")
    log_info(f"Estimated time: ~{config['test_time'] + 20}s")
    
    time.sleep(2)
    
    bench_start = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(hostnames)) as executor:
        futures = []
        for i, hostname in enumerate(hostnames):
            cmd = f'bash {remote_script_file} {core} {size} {pipeline} {startports[i]}'
            log_info(f"Launching on {hostname} (port base: {startports[i]})")
            futures.append(executor.submit(run_remote_command, hostname, port, username, password, cmd))
        
        for future in concurrent.futures.as_completed(futures):
            future.result()
    
    bench_duration = time.time() - bench_start
    log_success(f"Benchmark execution completed in {bench_duration:.2f}s")
    print()
    
    # Phase 3: Collect results
    print_header("PHASE 3: RESULTS COLLECTION")
    log_info("Aggregating results from all clients...")
    
    time.sleep(10)
    
    log_dir = f'/root/wls/redis/memtier_benchmark/log_{core}'
    for hostname in hostnames:
        run_remote_command(hostname, port, username, password, 
                          f'bash {remote_script_file2} {log_dir}',
                          collect_metrics=True)
    
    benchmark_stats['end_time'] = datetime.now()
    
    # Print summary
    print()
    print_summary(args, config)

if __name__ == "__main__":
    main()
