# btfs-status-contract

## Deploy

deploy btfs status contract to BTTC network, copy the code of contracts to Remix, deploy it with metamask

## Operation

deploy contracts will generate one contract:BtfsStatus

1. call BtfsStatus:reportStatus(...) to report status info from host node.
2. call BtfsStatus:getStatus(peer) to get status info.



# Basic Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
node scripts/deployAutoProxy.js
npx hardhat help
```
