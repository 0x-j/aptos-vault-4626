# ERC-4626 Vault on Aptos - Claude Code Context

Complete ERC-4626 implementation on Aptos with function value customization and single-contract architecture.

## Project Status: 🚧 IN DEVELOPMENT

**✅ Completed:**

- All ERC-4626 functions implemented with proper rounding
- Function value customization system for vault behavior
- Integration scripts package for easy deployment
- OpenZeppelin-compatible security features

**🚧 TODO before mainnet:**

- Comprehensive test suite
- Security audits
- Integration testing with real fungible assets
- Performance optimization
- Documentation and examples

## Reference Implementation

**OpenZeppelin ERC-4626:** https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC4626.sol?utm_source=chatgpt.com
- Use this as the canonical reference for ERC-4626 behavior
- Our implementation follows the same rounding strategies and security patterns
- Function signatures adapted for Move language and Aptos architecture

**Move Function Values:** https://aptos.dev/build/smart-contracts/book/functions#function-values
- Core Move feature enabling function customization per vault
- Allows each vault to override default behavior without contract inheritance

## Architecture

**Key Innovation:** Single contract handles all vaults (vs EVM's one-contract-per-vault)

- `vault-core`: Main contract implementation
- `scripts-only`: Integration scripts and examples
- All vaults share same contract address with object-based storage

## Core Implementation: `packages/vault-core/sources/vault_token.move`

**Complete Function Set:**

```move
// Core Operations
create_vault() - Factory with function value customization
deposit(assets) → shares - Floor rounding (user-favorable)
mint(shares) → assets - Ceil rounding (protocol-favorable)
withdraw(assets, receiver) → shares - Ceil rounding
redeem(shares, receiver) → assets - Floor rounding

// View Functions
convert_to_shares/assets() - Conversion utilities
max_*() / preview_*() - Limits and previews with custom logic
asset() / total_assets() - Basic vault info
```

**Key Features:**

- **Function Values:** Each vault customizes behavior via function parameters
- **Rounding Protection:** Implements OpenZeppelin-style rounding strategy
- **Inflation Protection:** Virtual assets/shares prevent first-depositor attacks
- **Events:** `VaultDepositEvent`, `VaultMintEvent`, `VaultWithdrawEvent`, `VaultRedeemEvent`

## Development Workflow

**Test & Deploy:**

```bash
cd packages/vault-core
./sh_scripts/test.sh       # Run Move tests
./sh_scripts/deploy.sh     # Deploy to network
```

**Create Vault:**

```bash
cd packages/scripts-only
./sh_scripts/run_create_vault.sh  # Execute creation script
```

## Configuration

- **Addresses:** `vault_core_addr = "_"` (mainnet), `0x999` (dev)
- **Dependencies:** AptosFramework (mainnet), VaultCore (local)
- **Language:** Move 2.2 with function values

## Common Tasks

**Add new functions:** Edit `vault_token.move`, update `VaultFunctions` struct, add default implementations

**Create custom vault:** Use `create_vault()` with function value parameters for custom behavior

**DeFi Integration:** Single contract interface works with all vaults:

```move
let shares = vault_token::deposit(user, underlying, vault_token, assets);
```

## Error Handling

- `ERR_UNDERLYING_TOKEN_MISMATCH: u64 = 1`
- `ERR_EXCEEDED_MAX_DEPOSIT: u64 = 2`
- `ERR_EXCEEDED_MAX_MINT: u64 = 3`
- `ERR_EXCEEDED_MAX_WITHDRAW: u64 = 4`
- `ERR_INSUFFICIENT_SHARES: u64 = 5`
- `ERR_EXCEEDED_MAX_REDEEM: u64 = 6`

## Key Files for Development

- `packages/vault-core/sources/vault_token.move` - Main implementation
- `packages/scripts-only/scripts/create_vault.move` - Creation example
- `packages/vault-core/contract_address.txt` - Deploy address
- `packages/*/sh_scripts/` - All development commands
