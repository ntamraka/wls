#!/usr/bin/env python3
"""
Remote Agent - Runs on remote machines and waits for commands from dashboard server
This agent connects to the dashboard and waits for benchmark execution commands.

Usage: python3 remote_agent.py <dashboard_server_ip:port> [machine_name]
Example: python3 remote_agent.py 10.140.157.132:8000 server-02
"""

import os
import sys

# CRITICAL: Disable ALL proxy settings BEFORE importing websockets
# This must happen before any network library imports
proxy_vars = [
    'http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY',
    'all_proxy', 'ALL_PROXY', 'ftp_proxy', 'FTP_PROXY',
    'socks_proxy', 'SOCKS_PROXY', 'no_proxy', 'NO_PROXY'
]

for var in proxy_vars:
    if var in os.environ:
        del os.environ[var]
        #print(f"[DEBUG] Removed proxy variable: {var}")

import asyncio
import websockets
import subprocess
import json
import socket
import signal

class RemoteAgent:
    def __init__(self, server_url, machine_id, config_file="benchmark_config.sh"):
        self.server_url = server_url
        self.machine_id = machine_id
        self.config_file = config_file
        self.running = True
        self.current_process = None
        # Get the directory where this script is located
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        print(f"[DEBUG] Script directory: {self.script_dir}")
        
    async def run_mlc_benchmark(self, websocket):
        """Run MLC benchmark and stream results"""
        print(f"[AGENT] Starting benchmark with config: {self.config_file}")
        
        try:
            # Build absolute paths for the script and config
            runner_script = os.path.join(self.script_dir, 'generic_runner.sh')
            
            # If config is relative, make it absolute relative to script dir
            if not os.path.isabs(self.config_file):
                config_path = os.path.join(self.script_dir, self.config_file)
            else:
                config_path = self.config_file
            
            print(f"[DEBUG] Runner: {runner_script}")
            print(f"[DEBUG] Config: {config_path}")
            print(f"[DEBUG] Working directory: {self.script_dir}")
            
            # Run the generic runner with the config, using script directory as cwd
            self.current_process = await asyncio.create_subprocess_exec(
                runner_script, config_path, self.machine_id,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.script_dir
            )
            
            # Read stderr in background
            async def read_stderr():
                try:
                    if self.current_process and self.current_process.stderr:
                        while True:
                            line = await self.current_process.stderr.readline()
                            if not line:
                                break
                            print(f"[DEBUG] {line.decode().strip()}")
                except Exception as e:
                    print(f"[DEBUG] stderr reader error: {e}")
            
            stderr_task = asyncio.create_task(read_stderr())
            
            # Stream output to dashboard
            data_sent = 0
            while True:
                line = await self.current_process.stdout.readline()
                if not line:
                    break
                    
                text = line.decode().strip()
                
                # Only send JSON lines
                if text.startswith('{') and text.endswith('}'):
                    try:
                        data = json.loads(text)
                        # Try to send data, catch if connection is closed
                        await websocket.send(json.dumps(data))
                        data_sent += 1
                        vms = data.get('cores', data.get('vms', '?'))
                        rps = data.get('requests', data.get('bandwidth', data.get('kpi', 0)))
                        # ANSI color codes: Cyan for VMs, Green for RPS
                        print(f"[AGENT] Sent data point {data_sent}: \033[96mVMs={vms}\033[0m, \033[92mRPS={rps}\033[0m")
                    except json.JSONDecodeError as e:
                        print(f"[ERROR] JSON decode error: {e}")
                    except (websockets.exceptions.ConnectionClosed, ConnectionError) as e:
                        print(f"[ERROR] Connection closed while sending data: {e}")
                        break
                    except Exception as e:
                        print(f"[ERROR] Failed to send data: {e}")
                        # Continue trying for other errors
                        
            await self.current_process.wait()
            await stderr_task
            
            print(f"[AGENT] Benchmark complete! Exit code: {self.current_process.returncode}, Data points sent: {data_sent}")
            
            # Small delay to ensure all data is transmitted
            await asyncio.sleep(0.5)
            
        except Exception as e:
            print(f"[ERROR] Benchmark execution error: {e}")
            import traceback
            traceback.print_exc()
            await websocket.send(json.dumps({
                "machine": self.machine_id,
                "status": "error",
                "error": str(e)
            }))
        finally:
            self.current_process = None
    
    async def handle_command(self, command, websocket):
        """Handle commands from dashboard server"""
        cmd_type = command.get('command')
        
        if cmd_type == 'run_benchmark':
            print(f"[AGENT] Received run_benchmark command")
            await self.run_mlc_benchmark(websocket)
            
        elif cmd_type == 'status':
            status = {
                "machine": self.machine_id,
                "status": "busy" if self.current_process else "idle",
                "type": "status_response"
            }
            await websocket.send(json.dumps(status))
            print(f"[AGENT] Status: {'busy' if self.current_process else 'idle'}")
            
        elif cmd_type == 'ping':
            await websocket.send(json.dumps({
                "machine": self.machine_id,
                "type": "pong"
            }))
            
        else:
            print(f"[AGENT] Unknown command: {cmd_type}")
    
    async def connect_and_listen(self):
        """Connect to dashboard and listen for commands"""
        uri = f"ws://{self.server_url}/ws/agent"
        retry_delay = 5
        
        while self.running:
            try:
                print(f"[AGENT] Connecting to dashboard at {uri}...")
                
                async with websockets.connect(uri) as websocket:
                    # Register with server
                    await websocket.send(json.dumps({
                        "type": "register",
                        "machine": self.machine_id,
                        "hostname": socket.gethostname()
                    }))
                    print(f"[AGENT] Connected and registered as '{self.machine_id}'")
                    
                    # Listen for commands
                    while self.running:
                        try:
                            message = await asyncio.wait_for(websocket.recv(), timeout=30.0)
                            command = json.loads(message)
                            await self.handle_command(command, websocket)
                            
                        except asyncio.TimeoutError:
                            # Send heartbeat
                            await websocket.send(json.dumps({
                                "machine": self.machine_id,
                                "type": "heartbeat"
                            }))
                            
                        except websockets.exceptions.ConnectionClosed:
                            print("[AGENT] Connection closed by server")
                            break
                            
            except websockets.exceptions.WebSocketException as e:
                print(f"[ERROR] WebSocket error: {e}")
                print(f"[AGENT] Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)
                
            except Exception as e:
                print(f"[ERROR] Unexpected error: {e}")
                print(f"[AGENT] Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)
    
    def shutdown(self):
        """Graceful shutdown"""
        print("\n[AGENT] Shutting down...")
        self.running = False
        if self.current_process:
            try:
                self.current_process.terminate()
            except:
                pass

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 remote_agent.py <server_ip:port> [machine_name] [config_file]")
        print("Example: python3 remote_agent.py 10.140.157.132:8000 server-02 benchmark_config.sh")
        sys.exit(1)
    
    server_url = sys.argv[1]
    machine_id = sys.argv[2] if len(sys.argv) > 2 else socket.gethostname()
    config_file = sys.argv[3] if len(sys.argv) > 3 else "benchmark_config.sh"
    
    print("=" * 60)
    print("         Remote Agent - Generic Benchmark Runner")
    print("=" * 60)
    print(f"Dashboard Server: {server_url}")
    print(f"Machine ID: {machine_id}")
    print(f"Config File: {config_file}")
    print(f"Hostname: {socket.gethostname()}")
    print("=" * 60)
    print("Agent is running and waiting for commands...")
    print("Press Ctrl+C to stop")
    print("=" * 60)
    
    agent = RemoteAgent(server_url, machine_id, config_file)
    
    # Handle Ctrl+C gracefully
    def signal_handler(sig, frame):
        agent.shutdown()
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        asyncio.run(agent.connect_and_listen())
    except KeyboardInterrupt:
        pass
    finally:
        print("[AGENT] Stopped")

if __name__ == "__main__":
    main()
