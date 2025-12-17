#!/usr/bin/env bash
set -e  # Exit on error

# Source .env file
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

forge script script/DeployXAUt.s.sol \
  --s "step2_TransferAdmin(address,address,address)" \
  $PROXY \
  $MULTISIG_ENGINEER \
  $TIMELOCK \
  -vvv \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast