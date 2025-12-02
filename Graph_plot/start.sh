#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting MLC Dashboard Server...${NC}"
echo -e "${YELLOW}Dashboard will be available at:${NC}"
echo -e "${GREEN}  http://localhost:8000${NC}"
echo -e "${GREEN}  http://$(hostname -I | awk '{print $1}'):8000${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

# Start server
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
