#!/bin/bash
# Simple script to trigger benchmarks on all connected remote agents via CLI

SERVER="${1:-localhost:8000}"

echo "Triggering benchmarks on all connected agents..."
echo "Server: $SERVER"
echo ""

python3 - <<EOF
import asyncio
import websockets
import json
import sys

async def trigger_benchmarks():
    uri = "ws://${SERVER}/ws/control"
    try:
        async with websockets.connect(uri) as websocket:
            # Get agent list
            await websocket.send(json.dumps({"command": "get_agents"}))
            response = await websocket.recv()
            data = json.loads(response)
            
            agents = data.get('agents', [])
            print(f"Connected agents: {agents}")
            
            if not agents:
                print("No agents connected!")
                return
            
            # Trigger run_all
            await websocket.send(json.dumps({"command": "run_all"}))
            print(f"✓ Triggered benchmark on {len(agents)} agent(s)")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

asyncio.run(trigger_benchmarks())
EOF

echo ""
echo "Done! Check the dashboard to see results."
