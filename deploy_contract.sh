#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== WEN MOVED Coin ($WENMO) Deployment Script ===${NC}"

# Check if movement CLI is installed
if ! command -v movement &> /dev/null; then
    echo -e "${RED}Error: 'movement' CLI is not installed.${NC}"
    echo "Please install it first: https://docs.movementnetwork.xyz/devs/movementcli"
    exit 1
fi

# Ask for profile
read -p "Enter Movement Profile to use (default: 'default'): " PROFILE
PROFILE=${PROFILE:-default}

echo -e "${BLUE}Using profile: ${PROFILE}${NC}"

# Check if profile exists and get address
echo "Fetching account address..."
ACCOUNT_ADDR=$(awk -v profile="$PROFILE" '$1 == profile":" {p=1} p && /account:/ {print $2; exit}' .movement/config.yaml)

if [ -z "$ACCOUNT_ADDR" ]; then
    echo -e "${RED}Could not find address for profile '$PROFILE'.${NC}"
    echo "Make sure you have run 'movement init --profile $PROFILE' and funded the account."
    exit 1
fi

echo -e "${GREEN}Deploying with Account: $ACCOUNT_ADDR${NC}"

# Confirm
read -p "Continue with deployment? (y/n): " CONFIRM
if [[ $CONFIRM != "y" ]]; then
    exit 0
fi

# Move to contracts dir
cd move_contracts

echo -e "${BLUE}--- Cleaning previous build ---${NC}"
rm -rf build

echo -e "${BLUE}--- Compiling Contract ---${NC}"
movement move compile \
    --named-addresses wenmo=$ACCOUNT_ADDR \
    --bytecode-version 6

if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed!${NC}"
    exit 1
fi

echo -e "${BLUE}--- Publishing Contract ---${NC}"
# Publish package
movement move publish \
    --named-addresses wenmo=$ACCOUNT_ADDR \
    --profile $PROFILE \
    --optimize=none \
    --bytecode-version 6 \
    --assume-yes

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Contract published successfully!${NC}"

echo -e "${BLUE}--- Initializing Token ---${NC}"
# Try to initialize token, but don't fail if already initialized
movement move run \
    --function-id $ACCOUNT_ADDR::wenmo_token::initialize \
    --profile $PROFILE \
    --assume-yes || echo "Token initialization failed (might be already initialized)"

echo -e "${BLUE}--- Initializing Faucet ---${NC}"
# Try to initialize faucet, but don't fail if already initialized
movement move run \
    --function-id $ACCOUNT_ADDR::wenmo_faucet::initialize_default \
    --profile $PROFILE \
    --assume-yes || echo "Faucet initialization failed (might be already initialized)"

echo -e "${BLUE}--- Funding Faucet ---${NC}"
# Fund faucet with 50% of supply (500,000,000 tokens)
# 500,000,000 * 10^8 = 50000000000000000
movement move run \
    --function-id $ACCOUNT_ADDR::wenmo_faucet::fund_faucet \
    --args u64:50000000000000000 \
    --profile $PROFILE \
    --assume-yes || echo "Faucet funding failed (might be network issue or insufficient balance)"

echo -e "${GREEN}Deployment steps completed (check errors above if any)${NC}"
echo -e "${BLUE}=== Deployment Complete ===${NC}"
echo -e "Contract Address: ${GREEN}$ACCOUNT_ADDR${NC}"
echo ""
echo -e "Next steps:"
echo "1. Update 'frontend/src/constants.js' with the address above."
echo "2. Run 'npm install' and 'npm run dev' in the frontend directory."
