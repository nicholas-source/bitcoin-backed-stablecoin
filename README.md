# Bitcoin-Backed Stablecoin Smart Contract

## Overview

This Clarity smart contract implements a Bitcoin-backed stablecoin system on the Stacks blockchain, providing a robust mechanism for creating, minting, redeeming, and liquidating crypto-collateralized stablecoins.

## Features

- **Vault Management**

  - Create Bitcoin-collateralized vaults
  - Mint stablecoins against Bitcoin collateral
  - Redeem stablecoins
  - Liquidate undercollateralized vaults

- **Advanced Security**

  - Strict authorization checks
  - Input validation
  - Comprehensive error handling
  - Configurable governance parameters

- **Oracle Integration**
  - Multiple price oracle support
  - Bitcoin price tracking
  - Price update mechanism

## Contract Architecture

### Key Components

1. **Vaults**

   - Unique vault creation for each user
   - Tracks collateral amount, minted stablecoins, and vault creation timestamp
   - Supports multiple vaults per user

2. **Stablecoin Configuration**

   - Configurable name and symbol
   - Dynamic total supply management
   - Adjustable collateralization ratio

3. **Governance**
   - Contract owner controls critical parameters
   - Ability to update collateralization ratio
   - Oracle management

### Error Handling

The contract includes detailed error codes for various scenarios:

- Unauthorized actions
- Insufficient balances
- Invalid collateral
- Undercollateralization
- Oracle price unavailability
- Liquidation failures
- Minting limit exceedance

## Key Functions

### `create-vault`

- Creates a new vault for a user
- Requires valid collateral amount
- Generates a unique vault ID

### `mint-stablecoin`

- Allows minting stablecoins against collateral
- Validates:
  - Vault ownership
  - Collateralization ratio
  - Minting limits
  - Oracle price

### `redeem-stablecoin`

- Enables users to redeem stablecoins
- Reduces vault's minted amount
- Updates total supply

### `liquidate-vault`

- Triggers vault liquidation when collateralization falls below threshold
- Prevents self-liquidation
- Removes undercollateralized vault

### Governance Functions

- `add-btc-price-oracle`: Add trusted price oracles
- `update-btc-price`: Update Bitcoin price
- `update-collateralization-ratio`: Adjust system parameters

## Configuration Parameters

- **Collateralization**

  - Minimum ratio: 150%
  - Liquidation threshold: 125%

- **Fees**

  - Minting fee: 0.5%
  - Redemption fee: 0.5%

- **Limits**
  - Maximum mint limit: 1,000,000 tokens
  - Maximum Bitcoin price: 1,000,000,000,000

## Security Considerations

- Strict access controls
- Price oracle validation
- Comprehensive input validation
- Prevents excessive vault and token creation
- Configurable liquidation mechanisms

## Installation and Deployment

### Prerequisites

- Stacks blockchain
- Clarity smart contract support
- Bitcoin price oracle infrastructure

### Deployment Steps

1. Deploy the contract on Stacks
2. Configure initial parameters
3. Add trusted price oracles
4. Set initial collateralization ratio

## Potential Improvements

- Dynamic fee adjustments
- More granular liquidation mechanisms
- Enhanced oracle redundancy
- Cross-chain collateral support

## Disclaimer

This smart contract is provided as-is. Users and developers should conduct thorough audits and testing before production use.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions to DAF Smart Contract! Please see our [Guide](CONTRIBUTING.md) for details on how to get started.
