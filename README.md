# Random Raffle Contracts

## About

This code will create random smart contract lottery.

## What it will do?

1. Users will enter by paying a ticked
   1. The ticket fee will go to the winner of the lottery
2. After x period of time, the lottery will automatically draw a winner
   1. That Will be done programatically
3. We will Use Chainlink VRF & Chainlink Automation
   1. Chainlink VRF for Randomness
   2. Chainlink Automation for time based trigger

# Test
1. We wrote deploy scripts
2. We have 3 different tests
   1. Test that work on a local chain
   2. Forked Testnet
   3. Forked Mainnet