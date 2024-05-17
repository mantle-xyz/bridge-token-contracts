#!/usr/bin/env bash

# example: 0xcDf9937b6a78cD86c871413CF9B4d79EC4B5Ea76
echo Please provide L2 token contract address to be verified.
read contract_address

forge verify-contract --verifier blockscout --watch \
    --verifier-url 'https://explorer.sepolia.mantle.xyz/api?module=contract&action=verify' \
    --compiler-version "v0.8.20+commit.a1b79de6" \
    --num-of-optimizations 200 \
    --chain 5003 \
    --constructor-args $(cast abi-encode "constructor(address,address)" 0x4200000000000000000000000000000000000010 0xcDf9937b6a78cD86c871413CF9B4d79EC4B5Ea76) \
    $contract_address src/ERC20Bridged.sol:ERC20Bridged