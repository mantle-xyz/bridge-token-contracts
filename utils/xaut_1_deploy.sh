#!/usr/bin/env bash
set -e  # Exit on error

# Source .env file
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

forge script script/DeployXAUt.s.sol \
  -s "step1_Deploy(address,address,address,uint256)" \
  $L2_BRIDGE \
  $L1_TOKEN \
  $MULTISIG_SEC \
  60 \
  -vvv \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier etherscan