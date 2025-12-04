import asyncio
import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os
from typing import Dict, Set

app = FastAPI()

# Enable CORS for all origins (adjust in production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Store active WebSocket connections
active_connections: Set[WebSocket] = set()  # Dashboard viewers
active_agents: Dict[str, WebSocket] = {}  # Remote agents {machine_id: websocket}

# ---------------------------------------------------------
# Serve the dashboard (index.html) from the project folder
# ---------------------------------------------------------
@app.get("/")
async def root():
    index_path = os.path.join(os.getcwd(), "index.html")
    if not os.path.exists(index_path):
        return {"error": "index.html not found in project directory"}
    return FileResponse(index_path)


# ---------------------------------------------------------
# WebSocket: streams JSON from your shell script
# ---------------------------------------------------------
@app.websocket("/ws")
async def ws_dashboard(ws: WebSocket):
    """Dashboard viewer connection - receives data broadcast from agents"""
    await ws.accept()
    active_connections.add(ws)
    print(f"[SERVER] Dashboard connection accepted. Total connections: {len(active_connections)}")

    try:
        # Keep connection open - receive messages if any (though dashboard doesn't send any)
        # Data will be broadcast to this connection from /ws/agent endpoint
        while True:
            try:
                # Wait for message with timeout to keep connection alive
                message = await asyncio.wait_for(ws.receive_text(), timeout=30.0)
                # Dashboard doesn't send messages, but just in case
                print(f"[DEBUG] Dashboard sent: {message}")
            except asyncio.TimeoutError:
                # No message in 30s, that's fine - connection is still alive
                # Send a ping to keep connection alive
                try:
                    await ws.send_json({"type": "ping"})
                except:
                    break
            
    except WebSocketDisconnect:
        print("[SERVER] Dashboard disconnected")
    except Exception as e:
        print(f"[ERROR] Dashboard WebSocket error: {e}")
    finally:
        active_connections.discard(ws)
        try:
            await ws.close()
        except:
            pass
        print(f"[SERVER] Dashboard connection closed. Remaining connections: {len(active_connections)}")


# ---------------------------------------------------------
# WebSocket: for remote clients to push data
# ---------------------------------------------------------
@app.websocket("/ws/push")
async def ws_push_data(ws: WebSocket):
    await ws.accept()
    print("[SERVER] Remote push connection accepted")
    
    try:
        while True:
            # Receive data from remote client
            data = await ws.receive_json()
            print(f"[SERVER] Received remote data: {data}")
            
            # Broadcast to all dashboard connections
            for connection in active_connections:
                try:
                    await connection.send_json(data)
                except:
                    pass
                    
    except WebSocketDisconnect:
        print("[SERVER] Remote push connection closed")
    except Exception as e:
        print(f"[ERROR] Push WebSocket error: {e}")
    finally:
        await ws.close()


# ---------------------------------------------------------
# WebSocket: for remote agents (persistent connections)
# ---------------------------------------------------------
@app.websocket("/ws/agent")
async def ws_agent(ws: WebSocket):
    await ws.accept()
    machine_id = None
    print("[SERVER] Agent connection accepted")
    
    try:
        # Wait for registration
        reg_msg = await ws.receive_json()
        if reg_msg.get('type') == 'register':
            machine_id = reg_msg.get('machine')
            active_agents[machine_id] = ws
            print(f"[SERVER] Agent registered: {machine_id} (Total agents: {len(active_agents)})")
            
            # Notify dashboards about new agent
            agent_list_msg = {
                "type": "agent_list",
                "agents": list(active_agents.keys())
            }
            for connection in active_connections:
                try:
                    await connection.send_json(agent_list_msg)
                except:
                    pass
        
        # Listen for messages from agent (benchmark results, status, etc.)
        while True:
            try:
                # Increased timeout to 300s (5 minutes) for long-running benchmarks
                message = await asyncio.wait_for(ws.receive_json(), timeout=300.0)
                msg_type = message.get('type')
                
                if msg_type == 'heartbeat':
                    # Just acknowledge, no action needed
                    pass
                elif msg_type in ['status_response', 'pong']:
                    # Forward to dashboards
                    for connection in active_connections:
                        try:
                            await connection.send_json(message)
                        except:
                            pass
                else:
                    # Benchmark data - broadcast to all dashboards
                    print(f"[DEBUG] Broadcasting to {len(active_connections)} dashboard(s)")
                    for connection in active_connections:
                        try:
                            await connection.send_json(message)
                            print(f"[DEBUG] Sent data to dashboard: {message}")
                        except Exception as e:
                            print(f"[DEBUG] Failed to send to dashboard: {e}")
                    
                    # Log if it's benchmark data
                    if 'cores' in message:
                        import datetime
                        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
                        vms = message.get('cores', message.get('vms', '?'))
                        rps = message.get('requests') or message.get('bandwidth') or message.get('kpi')
                        # ANSI color codes: Cyan for VMs, Green for RPS
                        print(f"[{timestamp}] Agent {machine_id} data: \033[96mVMs={vms}\033[0m, \033[92mRPS={rps}\033[0m")
                        
            except asyncio.TimeoutError:
                # No message in 60s, connection might be dead
                print(f"[SERVER] Agent {machine_id} timeout, checking connection...")
                break
                
    except WebSocketDisconnect:
        print(f"[SERVER] Agent {machine_id} disconnected")
    except Exception as e:
        print(f"[ERROR] Agent WebSocket error: {e}")
    finally:
        if machine_id and machine_id in active_agents:
            del active_agents[machine_id]
            print(f"[SERVER] Agent {machine_id} removed (Remaining: {len(active_agents)})")
            
            # Notify dashboards about agent removal
            agent_list_msg = {
                "type": "agent_list",
                "agents": list(active_agents.keys())
            }
            for connection in active_connections:
                try:
                    await connection.send_json(agent_list_msg)
                except:
                    pass
        
        await ws.close()


# ---------------------------------------------------------
# WebSocket: control endpoint to trigger benchmarks on agents
# ---------------------------------------------------------
@app.websocket("/ws/control")
async def ws_control(ws: WebSocket):
    await ws.accept()
    print("[SERVER] Control connection accepted")
    
    try:
        while True:
            command = await ws.receive_json()
            cmd_type = command.get('command')
            
            if cmd_type == 'run_all':
                print(f"[SERVER] Running benchmark on all {len(active_agents)} agents")
                for machine_id, agent_ws in active_agents.items():
                    try:
                        await agent_ws.send_json({"command": "run_benchmark"})
                        print(f"[SERVER] Sent run_benchmark to {machine_id}")
                    except Exception as e:
                        print(f"[ERROR] Failed to send to {machine_id}: {e}")
                        
            elif cmd_type == 'run_specific':
                machine_ids = command.get('machines', [])
                print(f"[SERVER] Running benchmark on specific machines: {machine_ids}")
                for machine_id in machine_ids:
                    if machine_id in active_agents:
                        try:
                            await active_agents[machine_id].send_json({"command": "run_benchmark"})
                            print(f"[SERVER] Sent run_benchmark to {machine_id}")
                        except Exception as e:
                            print(f"[ERROR] Failed to send to {machine_id}: {e}")
                    else:
                        print(f"[WARNING] Machine {machine_id} not connected")
                        
            elif cmd_type == 'get_agents':
                await ws.send_json({
                    "type": "agent_list",
                    "agents": list(active_agents.keys())
                })
                
            elif cmd_type == 'status_check':
                print(f"[SERVER] Checking status of all agents")
                for machine_id, agent_ws in active_agents.items():
                    try:
                        await agent_ws.send_json({"command": "status"})
                    except:
                        pass
                        
    except WebSocketDisconnect:
        print("[SERVER] Control connection closed")
    except Exception as e:
        print(f"[ERROR] Control WebSocket error: {e}")
    finally:
        await ws.close()


# ---------------------------------------------------------
# Startup entry point
# ---------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run("server:app",
                host="0.0.0.0",
                port=8000,
                reload=True)
