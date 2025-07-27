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

**Implemented:**

- `create_vault()` - Creates a new vault for an underlying token
- `deposit()` - Deposits assets and mints shares
- `asset()` - Returns the underlying asset
- `total_assets()` - Returns total assets in vault
- `max_deposit()` - Returns maximum deposit allowed
- `preview_deposit()` - Previews shares for deposit

**Stubbed (abort 0):**

- `mint()`, `withdraw()`, `redeem()`
- `convert_to_shares()`, `convert_to_assets()`
- `max_mint()`, `preview_mint()`
- `max_withdraw()`, `preview_withdraw()`
- `max_redeem()`, `preview_redeem()`

#### Custom Function Support

The vault supports custom implementations of all ERC-4626 functions through lambda parameters in `create_vault()`, allowing for flexible vault behavior customization.

#### Events

- `CreateVaultEvent` - Emitted when vault is created
- `DepositEvent` - Emitted on deposits
- `WithdrawEvent` - Emitted on withdrawals

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

## Current State

This is a work-in-progress implementation:

✅ **Completed:**

- Basic vault creation and structure
- Deposit functionality with events
- Asset and total assets view functions
- Customizable function framework with lambdas
- Default implementations for core functions

🚧 **In Progress/TODO:**

- Complete mint, withdraw, redeem functions
- Implement convert_to_shares/convert_to_assets
- Add proper rounding logic
- Complete all preview functions
- Add comprehensive tests
- Implement max\_\* functions for mint/withdraw/redeem

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
