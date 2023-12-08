
## BCKGov Smart Contract System Documentation

### Overview
This document provides a comprehensive guide on deploying and interacting with the BCKGov Smart Contract System. The system is composed of multiple contracts, each serving a specific function within the ecosystem.

### Prerequisites
Before proceeding, ensure you have a Solidity environment set up for deploying smart contracts, such as Truffle or Hardhat, and a wallet configured with sufficient Ethereum for deploying contracts.

### Step-by-Step Guide

#### 1. Deploy All Contracts
Begin by deploying all the necessary contracts. This includes:
- `TokenFactory`
- `EmissionsFactory`
- `YieldToBCKFactory`
- `VestingContractFactory`
- `GlobalsFactory`
- `SavingsAccountFactory`
- `GuardFactory`
- `buyTokensTestnet`
- `Deployer`

#### 2. Initialize Deployer Contract
After deploying these contracts, initialize the `Deployer` contract with the addresses of the above-deployed contracts.

#### 3. Execute Deployment Steps
Within the `Deployer` contract, execute the deployment steps in order:

- **Step 1 - `makeTokens`:** This step creates the required tokens (BCK, eUSD, esBCKGOV, BCKGOV) and sets up global parameters.
- **Step 2 - `makeContracts`:** Deploy the core contracts of the ecosystem using the tokens' addresses created in step 1.
- **Step 3 - `config`:** Configure the newly deployed contracts, setting up emission rates, stake minimums, and other vital parameters.
- **Step 4 - `configAuth`:** Establish authority settings for the contracts, ensuring correct permissions and access control.

- To interact with shares(), and totaldeposits() for calculating spending limit on the cashback app, use the globalparams address generated, and also global.sol abi