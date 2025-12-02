#!/bin/bash
# Quick Setup Script for Multi-Machine Benchmark Dashboard
# This script sets up either dashboard server or workload agent

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  MLC Dashboard Setup Wizard${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Detect setup mode
echo -e "${YELLOW}Select setup mode:${NC}"
echo "  1) Dashboard Server (runs dashboard + workload)"
echo "  2) Workload Agent Only (remote machine)"
echo ""
read -p "Enter choice [1-2]: " SETUP_MODE

if [ "$SETUP_MODE" == "1" ]; then
    echo -e "${BLUE}Setting up Dashboard Server...${NC}"
    
    # Run main setup
    ./setup.sh
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Dashboard Server Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo -e "1. Start the dashboard server:"
    echo -e "   ${GREEN}./start.sh${NC}"
    echo ""
    echo -e "2. The dashboard will be available at:"
    echo -e "   ${GREEN}http://$(hostname -I | awk '{print $1}'):8000${NC}"
    echo ""
    echo -e "3. To test locally on this machine:"
    echo -e "   ${GREEN}./generic_runner.sh benchmark_config.sh${NC}"
    echo ""
    echo -e "4. To set up remote machines:"
    echo -e "   ${YELLOW}On each remote machine, run:${NC}"
    echo -e "   ${GREEN}./quick_setup.sh${NC}"
    echo -e "   ${YELLOW}and select option 2 (Workload Agent)${NC}"
    echo ""
    
elif [ "$SETUP_MODE" == "2" ]; then
    echo -e "${BLUE}Setting up Workload Agent...${NC}"
    
    # Get dashboard server IP
    echo ""
    read -p "Enter Dashboard Server IP address: " DASHBOARD_IP
    read -p "Enter Dashboard Server Port [8000]: " DASHBOARD_PORT
    DASHBOARD_PORT=${DASHBOARD_PORT:-8000}
    
    read -p "Enter Machine Name [$(hostname)]: " MACHINE_NAME
    MACHINE_NAME=${MACHINE_NAME:-$(hostname)}
    
    read -p "Enter Config File [benchmark_config.sh]: " CONFIG_FILE
    CONFIG_FILE=${CONFIG_FILE:-benchmark_config.sh}
    
    # Run main setup
    ./setup.sh
    
    # Create start script for agent
    cat > start_agent.sh << EOF
#!/bin/bash
# Auto-generated agent startup script

echo "Starting benchmark agent..."
echo "Dashboard: ${DASHBOARD_IP}:${DASHBOARD_PORT}"
echo "Machine: ${MACHINE_NAME}"
echo "Config: ${CONFIG_FILE}"
echo ""

python3 remote_agent.py ${DASHBOARD_IP}:${DASHBOARD_PORT} ${MACHINE_NAME} ${CONFIG_FILE}
EOF
    
    chmod +x start_agent.sh
    
    # Test connection
    echo ""
    echo -e "${YELLOW}Testing connection to dashboard...${NC}"
    if timeout 3 bash -c "</dev/tcp/${DASHBOARD_IP}/${DASHBOARD_PORT}" 2>/dev/null; then
        echo -e "${GREEN}✓ Connection successful!${NC}"
    else
        echo -e "${RED}✗ Cannot reach dashboard at ${DASHBOARD_IP}:${DASHBOARD_PORT}${NC}"
        echo -e "${YELLOW}  Make sure:${NC}"
        echo -e "  - Dashboard server is running"
        echo -e "  - Port ${DASHBOARD_PORT} is open"
        echo -e "  - Network connectivity exists"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Workload Agent Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "  Dashboard: ${GREEN}${DASHBOARD_IP}:${DASHBOARD_PORT}${NC}"
    echo -e "  Machine: ${GREEN}${MACHINE_NAME}${NC}"
    echo -e "  Config: ${GREEN}${CONFIG_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}To start the agent:${NC}"
    echo -e "  ${GREEN}./start_agent.sh${NC}"
    echo ""
    echo -e "${YELLOW}The agent will:${NC}"
    echo -e "  - Connect to dashboard server"
    echo -e "  - Wait for benchmark commands"
    echo -e "  - Execute when triggered from dashboard"
    echo -e "  - Stream results in real-time"
    echo ""
    echo -e "${YELLOW}To manually start with different settings:${NC}"
    echo -e "  ${GREEN}python3 remote_agent.py <server_ip:port> <machine_name> [config_file]${NC}"
    echo ""
    
else
    echo -e "${RED}Invalid choice!${NC}"
    exit 1
fi
