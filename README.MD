# ERC-4626 Tokenized Vaults on Aptos

A complete implementation of the ERC-4626 tokenized vault standard on the Aptos blockchain, reimagined for the Move ecosystem with enhanced flexibility and efficiency.

> [!WARNING]
> This contract depends on [function values](https://aptos.dev/build/smart-contracts/book/functions#function-values) which is not yet available on mainnet as of 07/27/2025.

## What is ERC-4626?

ERC-4626 is the "Tokenized Vault Standard" - a standardized API for tokenized yield-bearing vaults. Originally designed for Ethereum, it defines a standard interface for depositing assets into yield-generating strategies and receiving shares representing ownership.

### Core Concepts

**Vaults** are smart contracts that:

- Accept deposits of an underlying asset (like USDC, ETH)
- Issue vault shares representing proportional ownership
- Implement yield-generating strategies with the deposited assets
- Allow shareholders to redeem shares for underlying assets plus yield

**Key Benefits:**

- **Composability:** Standard interface enables DeFi protocol integration
- **Yield Optimization:** Automated strategies maximize returns
- **Risk Sharing:** Diversified yield strategies across multiple users
- **Transparency:** On-chain visibility of all operations

## EVM vs Aptos: Architectural Innovation

### Traditional EVM Implementation

In the EVM ecosystem, each vault is a separate smart contract:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   USDC Vault    │    │   WETH Vault    │    │   DAI Vault     │
│   Contract      │    │   Contract      │    │   Contract      │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ Address: 0x123  │    │ Address: 0x456  │    │ Address: 0x789  │
│ - deposit()     │    │ - deposit()     │    │ - deposit()     │
│ - withdraw()    │    │ - withdraw()    │    │ - withdraw()    │
│ - balanceOf()   │    │ - balanceOf()   │    │ - balanceOf()   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**DeFi Integration Challenges:**

- Must integrate with each vault contract separately
- Different deployment addresses to track
- Inconsistent implementations across vault creators
- High gas costs for deployment per vault

### Our Aptos Implementation

Our approach uses a **single contract with vault objects**:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Single VaultCore Contract                    │
│                     Address: 0xVAULT_CORE                       │
├─────────────────────────────────────────────────────────────────┤
│  vault_token::deposit(vault_id, assets)                         │
│  vault_token::withdraw(vault_id, assets, receiver)              │
│  vault_token::mint(vault_id, shares)                            │
│  vault_token::redeem(vault_id, shares, receiver)                │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Vault Objects                            │
├─────────────────┬─────────────────┬─────────────────┬───────────┤
│   USDC Vault    │   WETH Vault    │   DAI Vault     │    ...    │
│   Object        │   Object        │   Object        │           │
├─────────────────┼─────────────────┼─────────────────┼───────────┤
│ Custom Logic:   │ Custom Logic:   │ Custom Logic:   │           │
│ ƒ convert_to_*  │ ƒ convert_to_*  │ ƒ convert_to_*  │           │
│ ƒ max_deposit   │ ƒ max_deposit   │ ƒ max_deposit   │           │
│ ƒ preview_*     │ ƒ preview_*     │ ƒ preview_*     │           │
└─────────────────┴─────────────────┴─────────────────┴───────────┘
```

### Key Advantages

| Aspect              | EVM ERC-4626                         | Our Aptos Implementation |
| ------------------- | ------------------------------------ | ------------------------ |
| **Deployment**      | New contract per vault (~$100-1000s) | Object creation (~$0.01) |
| **Integration**     | Track multiple contract addresses    | Single contract address  |
| **Discoverability** | Search across network                | Query one contract       |
| **Customization**   | Override contract functions          | Function values          |
| **Gas Efficiency**  | High deployment costs                | Minimal object costs     |
| **DeFi Adoption**   | Complex multi-contract integration   | Drop-in single interface |

## Advanced Features

### 1. Function Value Customization

Unlike EVM implementations that require contract inheritance, our vaults use **function values** for customization:

```move
vault_token::create_vault(
    &creator,
    underlying_asset,
    option::some(|vault, assets| {
        // Custom conversion logic
        my_custom_conversion(vault, assets)
    }),
    option::some(|vault, owner| {
        // Custom deposit limits
        get_user_deposit_limit(owner)
    }),
    // ... other custom functions
);
```

**Benefits:**

- **Flexible:** Each vault can have completely different behavior
- **Efficient:** No contract deployment overhead
- **Upgradeable:** Logic can be updated per vault
- **Composable:** Mix and match different strategies

### 2. OpenZeppelin-Compatible Rounding

Implements the same rounding strategies as OpenZeppelin to prevent exploitation:

- **User-favorable operations** (deposit, redeem): Floor rounding
- **Protocol-favorable operations** (mint, withdraw): Ceiling rounding
- **Inflation attack protection** via virtual assets/shares

### 3. Enhanced Security

- **Virtual Assets Protection:** Prevents first-depositor inflation attacks
- **Overflow Protection:** Safe math with proper rounding
- **Access Control:** Customizable per-vault permissions
- **Event Transparency:** Comprehensive event logging

## Use Cases & Applications

### For Yield Farmers

- **Automated Strategies:** Set-and-forget yield optimization
- **Risk Diversification:** Multiple strategies in one interface
- **Gas Efficiency:** Lower costs for vault creation and management

### For DeFi Protocols

- **Easy Integration:** Single contract interface for all vaults
- **Predictable Behavior:** Standard ERC-4626 compliance
- **Reduced Complexity:** No need to track multiple vault contracts

### For Vault Creators

- **Low Barrier to Entry:** Minimal deployment costs
- **Maximum Flexibility:** Custom logic via function values
- **Instant Composability:** Immediate DeFi ecosystem access

## Getting Started

### Quick Start

1. **Deploy the core contract:**

   ```bash
   cd packages/vault-core
   ./sh_scripts/deploy.sh
   ```

2. **Create your first vault:**

   ```bash
   cd packages/scripts-only
   ./sh_scripts/run_create_vault.sh
   ```

3. **Integrate with your DeFi protocol:**
   ```move
   // Single interface works with ALL vaults
   let shares = vault_token::deposit(user, underlying, vault_id, assets);
   let assets = vault_token::redeem(user, underlying, vault_id, shares, receiver);
   ```

### Architecture Deep Dive

For developers looking to understand the implementation details, see [CLAUDE.md](./CLAUDE.md) for:

- Complete function reference
- Development commands
- Integration examples
- Technical specifications

## Contributing

We welcome contributions! This implementation showcases how traditional Ethereum standards can be reimagined for modern blockchain architectures while maintaining compatibility and enhancing functionality.

## License

[Add your chosen license here]

---

**Built with Move on Aptos** - Showcasing the future of tokenized yield strategies
