#!/usr/bin/env python3
"""
Remote MLC Client - Run this on other machines to send data to central dashboard
Usage: python3 remote_client.py <dashboard_server_ip:port> [machine_name]
Example: python3 remote_client.py 10.140.157.132:8000 server-02
"""

import asyncio
import websockets
import subprocess
import json
import sys
import socket

async def run_mlc_and_stream(server_url, machine_id):
    """Run MLC benchmark and stream results to central server"""
    
    uri = f"ws://{server_url}/ws/push"
    print(f"Connecting to dashboard at {uri}")
    
    try:
        async with websockets.connect(uri) as websocket:
            print(f"Connected! Running MLC benchmark as '{machine_id}'...")
            
            # Run the MLC script
            process = await asyncio.create_subprocess_exec(
                './mlc.sh', machine_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            # Stream output to dashboard
            while True:
                line = await process.stdout.readline()
                if not line:
                    break
                    
                text = line.decode().strip()
                
                # Only send JSON lines
                if text.startswith('{') and text.endswith('}'):
                    try:
                        data = json.loads(text)
                        await websocket.send(json.dumps(data))
                        print(f"Sent: cores={data.get('cores')}, bw={data.get('bandwidth')}, lat={data.get('latency')}")
                    except json.JSONDecodeError as e:
                        print(f"JSON error: {e}")
                        
            await process.wait()
            print(f"Benchmark complete! Exit code: {process.returncode}")
            
    except websockets.exceptions.WebSocketException as e:
        print(f"WebSocket error: {e}")
        print("Make sure the dashboard server is running and accessible")
    except FileNotFoundError:
        print("Error: mlc.sh not found in current directory")
        print("Make sure you're running this from the Graph_plot directory")
    except Exception as e:
        print(f"Error: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 remote_client.py <server_ip:port> [machine_name]")
        print("Example: python3 remote_client.py 10.140.157.132:8000 server-02")
        sys.exit(1)
    
    server_url = sys.argv[1]
    machine_id = sys.argv[2] if len(sys.argv) > 2 else socket.gethostname()
    
    print(f"=== Remote MLC Client ===")
    print(f"Dashboard Server: {server_url}")
    print(f"Machine ID: {machine_id}")
    print("=" * 40)
    
    asyncio.run(run_mlc_and_stream(server_url, machine_id))

if __name__ == "__main__":
    main()
