#!/usr/bin/env bash

# Read the RPC URL
source .env

forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY --legacy \
    src/ERC20Bridged.sol:ERC20Bridged \
    --constructor-args \
        0x4200000000000000000000000000000000000010 \
        0xcDf9937b6a78cD86c871413CF9B4d79EC4B5Ea76 \