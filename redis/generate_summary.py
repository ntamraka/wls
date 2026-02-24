#!/usr/bin/env python3
"""
Parse all 2client_scalling_data.txt files and generate a summary CSV
"""

import os
import re
import csv
import glob

def parse_benchmark_file(filepath):
    """Extract benchmark results from a file"""
    result = {
        'file': os.path.basename(filepath),
        'core': None,
        'size': None,
        'pipe': None,
        'client1_iops': None,
        'client2_iops': None,
        'total_iops': None,
        'average_iops': None
    }
    
    # Extract from filename: Redis_ping_pipe-1_size-64_core-4_dmr_2client_scalling_data.txt
    filename = os.path.basename(filepath)
    
    # Parse pipe
    pipe_match = re.search(r'pipe-(\d+)', filename)
    if pipe_match:
        result['pipe'] = int(pipe_match.group(1))
    
    # Parse size
    size_match = re.search(r'size-(\d+)', filename)
    if size_match:
        result['size'] = int(size_match.group(1))
    
    # Parse core
    core_match = re.search(r'core-(\d+)', filename)
    if core_match:
        result['core'] = int(core_match.group(1))
    
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read()
            
            # Find Performance Results section
            # Pattern: IP_ADDRESS    XXX,XXX.XX ops/sec (N instances)
            client_iops = []
            for match in re.finditer(r'192\.168\.\d+\.\d+\s+([\d,]+\.\d+)\s+ops/sec', content):
                iops_str = match.group(1).replace(',', '')
                client_iops.append(float(iops_str))
            
            if len(client_iops) >= 2:
                result['client1_iops'] = client_iops[0]
                result['client2_iops'] = client_iops[1]
            elif len(client_iops) == 1:
                result['client1_iops'] = client_iops[0]
            
            # Find Total Throughput
            total_match = re.search(r'Total Throughput:\s+([\d,]+\.\d+)\s+ops/sec', content)
            if total_match:
                result['total_iops'] = float(total_match.group(1).replace(',', ''))
            
            # Find Average per Client
            avg_match = re.search(r'Average per Client:\s+([\d,]+\.\d+)\s+ops/sec', content)
            if avg_match:
                result['average_iops'] = float(avg_match.group(1).replace(',', ''))
                
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
    
    return result

def main():
    # Find all 2client_scalling_data.txt files
    redis_dir = '/root/wls/redis'
    pattern = os.path.join(redis_dir, '*2client_scalling_data.txt')
    files = glob.glob(pattern)
    
    if not files:
        print("No 2client_scalling_data.txt files found!")
        return
    
    print(f"Found {len(files)} files to process")
    
    results = []
    for filepath in sorted(files):
        print(f"Processing: {os.path.basename(filepath)}")
        result = parse_benchmark_file(filepath)
        results.append(result)
    
    # Sort by pipe, size, core
    results.sort(key=lambda x: (x['pipe'] or 0, x['size'] or 0, x['core'] or 0))
    
    # Write CSV
    output_file = os.path.join(redis_dir, 'summary_2client_scaling.csv')
    
    fieldnames = ['file', 'core', 'size', 'pipe', 'client1_iops', 'client2_iops', 'total_iops', 'average_iops']
    
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            writer.writerow(row)
    
    print(f"\nSummary written to: {output_file}")
    print(f"\nResults Preview:")
    print("-" * 100)
    print(f"{'File':<60} {'Core':>6} {'Size':>6} {'Pipe':>6} {'Total IOPS':>15}")
    print("-" * 100)
    for r in results:
        total = f"{r['total_iops']:,.0f}" if r['total_iops'] else "N/A"
        print(f"{r['file']:<60} {r['core'] or 'N/A':>6} {r['size'] or 'N/A':>6} {r['pipe'] or 'N/A':>6} {total:>15}")

if __name__ == '__main__':
    main()
