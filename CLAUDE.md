# ERC-4626 Vault Implementation on Aptos

This project implements the ERC-4626 tokenized vault standard on the Aptos blockchain using Move language.

## Project Structure

```
aptos-vault-4626/
├── README.md
└── packages/
    └── vault-core/
        ├── Move.toml                 # Package configuration
        ├── contract_address.txt      # Deployed contract address
        ├── sources/
        │   └── vault_token.move      # Main vault implementation
        ├── tests/
        │   └── test_end_to_end.move  # End-to-end tests (currently stub)
        ├── scripts/
        │   ├── create_2_messages.move
        │   └── update_message.move
        └── sh_scripts/               # Shell scripts for development
            ├── deploy.sh
            ├── fmt.sh
            ├── get_abis.sh
            ├── init.sh
            ├── test.sh
            └── upgrade.sh
```

## Core Implementation

### Main Module: `vault_core_addr::vault_token`

Located at: `packages/vault-core/sources/vault_token.move`

The implementation provides:

#### Key Structures

- **VaultState**: Tracks underlying token and total assets
- **VaultFunctions**: Customizable function implementations using lambdas
- **VaultController**: Manages vault operations (extend, transfer, mint, burn refs)

#### ERC-4626 Functions

**✅ Complete Implementation:**

**Core Operations:**

- `create_vault()` - Creates a new vault for an underlying token
- `deposit(assets)` - Deposits assets and mints shares (floor rounding)
- `mint(shares)` - Mints shares and collects assets (ceil rounding)
- `withdraw(assets, receiver)` - Withdraws assets and burns shares (ceil rounding)
- `redeem(shares, receiver)` - Redeems shares and returns assets (floor rounding)

**View Functions:**

- `asset()` - Returns the underlying asset
- `total_assets()` - Returns total assets in vault
- `convert_to_shares()` - Converts assets to shares (floor rounding)
- `convert_to_assets()` - Converts shares to assets (floor rounding)
- `max_deposit()`, `max_mint()`, `max_withdraw()`, `max_redeem()` - Maximum operation limits
- `preview_deposit()`, `preview_mint()`, `preview_withdraw()`, `preview_redeem()` - Preview functions

#### Custom Function Support

The vault supports custom implementations of all ERC-4626 functions through lambda parameters in `create_vault()`, allowing for flexible vault behavior customization.

#### Events

- `CreateVaultEvent` - Emitted when vault is created
- `DepositEvent` - Emitted on deposits
- `WithdrawEvent` - Emitted on withdrawals

## Architecture: Aptos vs EVM Approach

### EVM ERC-4626 Pattern

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vault A       │    │   Vault B       │    │   Vault C       │
│   Contract      │    │   Contract      │    │   Contract      │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ - deposit()     │    │ - deposit()     │    │ - deposit()     │
│ - withdraw()    │    │ - withdraw()    │    │ - withdraw()    │
│ - mint()        │    │ - mint()        │    │ - mint()        │
│ - redeem()      │    │ - redeem()      │    │ - redeem()      │
│ - asset: USDC   │    │ - asset: WETH   │    │ - asset: DAI    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
      │                        │                        │
      ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ DeFi Protocol   │    │ DeFi Protocol   │    │ DeFi Protocol   │
│ integrates with │    │ integrates with │    │ integrates with │
│ each contract   │    │ each contract   │    │ each contract   │
│ separately      │    │ separately      │    │ separately      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Aptos Approach (This Implementation)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Single VaultCore Contract                    │
├─────────────────────────────────────────────────────────────────┤
│                        Public Interface                         │
│  - create_vault()                                               │
│  - deposit(vault_token, assets)                                 │
│  - withdraw(vault_token, assets, receiver)                      │
│  - mint(vault_token, shares)                                    │
│  - redeem(vault_token, shares, receiver)                        │
│  - [all view functions]                                         │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Vault Instances                          │
├─────────────────┬─────────────────┬─────────────────┬───────────┤
│   Vault A       │   Vault B       │   Vault C       │    ...    │
│   Object        │   Object        │   Object        │           │
├─────────────────┼─────────────────┼─────────────────┼───────────┤
│ State:          │ State:          │ State:          │           │
│ - asset: USDC   │ - asset: WETH   │ - asset: DAI    │           │
│ - total_assets  │ - total_assets  │ - total_assets  │           │
│                 │                 │                 │           │
│ Custom Funcs:   │ Custom Funcs:   │ Custom Funcs:   │           │
│ - λ deposit     │ - λ deposit     │ - λ deposit     │           │
│ - λ withdraw    │ - λ withdraw    │ - λ withdraw    │           │
│ - λ max_*       │ - λ max_*       │ - λ max_*       │           │
└─────────────────┴─────────────────┴─────────────────┴───────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DeFi Integration                           │
│                                                                 │
│  DeFi protocols integrate with ONE contract address:            │
│  - Single interface to learn                                    │
│  - Consistent function signatures                               │
│  - Pass vault_token parameter to specify which vault            │
│  - Same contract handles all vault types                        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Differences

| Aspect                  | EVM ERC-4626                                       | Aptos Implementation                       |
| ----------------------- | -------------------------------------------------- | ------------------------------------------ |
| **Contract Deployment** | Each vault = new contract deployment               | All vaults use same contract               |
| **DeFi Integration**    | Must integrate with each vault contract separately | Single contract interface for all vaults   |
| **Customization**       | Override contract functions                        | Lambda functions in VaultFunctions struct  |
| **Gas/Fees**            | Deployment cost per vault                          | Only object creation cost                  |
| **Discoverability**     | Find vault contracts across network                | Query single contract for all vaults       |
| **Upgrades**            | Each vault contract needs upgrade                  | Single contract upgrade affects all vaults |

## Development Commands

### Testing

```bash
./packages/vault-core/sh_scripts/test.sh
# Runs: aptos move test --dev --language-version 2.2
```

### Formatting

```bash
./packages/vault-core/sh_scripts/fmt.sh
```

### Deployment

```bash
./packages/vault-core/sh_scripts/deploy.sh
```

## Configuration

### Move.toml

- Package: VaultCore v1.0.0
- Address: `vault_core_addr = "_"` (mainnet), `0x999` (dev)
- Dependencies: AptosFramework (mainnet branch)

## Implementation Status

🎉 **Complete ERC-4626 Implementation:**

✅ **Core Functions:**

- `create_vault()` - Vault factory with customizable behavior
- `deposit()` - Assets → Shares (user-favorable rounding)
- `mint()` - Shares → Assets (protocol-favorable rounding)
- `withdraw()` - Assets out → Shares burned (protocol-favorable rounding)
- `redeem()` - Shares → Assets (user-favorable rounding)

✅ **View Functions:**

- `convert_to_shares()` / `convert_to_assets()` - Conversion utilities
- `max_*()` functions - Operation limits with customizable logic
- `preview_*()` functions - Preview calculations with proper rounding
- `asset()` / `total_assets()` - Basic vault information

✅ **Advanced Features:**

- **Custom Rounding Logic:** Implements OpenZeppelin-compatible rounding with overflow protection
- **Lambda Customization:** Each vault can override any function behavior
- **Inflation Attack Protection:** Virtual assets/shares mechanism
- **Event System:** Comprehensive event emission for all operations
- **Error Handling:** Proper validation and error messages

✅ **DeFi Integration Ready:**

- Standard ERC-4626 interface for easy protocol integration
- Single contract address for all vault interactions
- Consistent function signatures across all vault types

🚧 **Next Steps:**

- Add comprehensive test suite
- Deploy to testnet/mainnet
- Create integration examples for DeFi protocols

## DeFi Integration Guide

### For Vault Creators

```move
// Create a vault with custom logic
vault_token::create_vault(
    &creator_signer,
    underlying_asset,
    option::some(custom_convert_to_assets_fn),
    option::some(custom_convert_to_shares_fn),
    option::some(custom_preview_deposit_fn),
    // ... other custom functions
);
```

### For DeFi Protocols

```move
// Single contract integration - works with ALL vaults
module defi_protocol {
    public fun integrate_with_vault(
        user: &signer,
        vault_token: Object<Metadata>
    ) {
        // Get vault info
        let underlying = vault_token::asset(vault_token);
        let total_assets = vault_token::total_assets(vault_token);

        // Deposit into vault
        let shares = vault_token::deposit(user, underlying, vault_token, amount);

        // Later: withdraw from vault
        let withdrawn = vault_token::withdraw(user, underlying, vault_token, amount, receiver);
    }
}
```

### Advantages for DeFi Ecosystem

1. **Single Integration Point:** Learn one interface, work with all vaults
2. **Predictable Behavior:** All vaults follow ERC-4626 standard
3. **Easy Discovery:** Query one contract for all available vaults
4. **Cost Efficiency:** No need to track multiple contract addresses
5. **Consistent Events:** Standardized event structure across all vaults

## Technical Notes

- Uses Aptos Framework's `fungible_asset` and `primary_fungible_store`
- Implements ERC-4626 standard adapted for Move/Aptos
- Uses object-based approach for vault tokens
- Supports customization through lambda functions
- Language version 2.2 for latest Move features

## Key Files to Monitor

- `packages/vault-core/sources/vault_token.move` - Main implementation
- `packages/vault-core/tests/test_end_to_end.move` - Test coverage
- `packages/vault-core/Move.toml` - Package configuration
