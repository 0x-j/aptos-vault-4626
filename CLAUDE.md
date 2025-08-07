# ERC-4626 Vault on Aptos - Claude Code Context

Complete ERC-4626 implementation on Aptos with function value customization and single-contract architecture.

## Project Status: 🟡 TESTNET READY

**✅ Completed:**

- All ERC-4626 functions implemented with proper rounding
- Function value customization system for vault behavior
- **SECURITY AUDIT COMPLETE** - All critical vulnerabilities resolved
- OpenZeppelin-compatible security features with proper authorization
- Fungible store patterns following Aptos conventions
- Clean architecture with external dispatch setup capability
- Dummy vault example for testing integration

**🚧 TODO before mainnet:**

- Comprehensive test suite with real fungible assets
- ERC-4626 compliance improvements (receiver/owner parameters)
- Performance optimization and gas analysis
- Multi-vault integration testing
- Final security review

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

- `vault-core`: Main contract implementation with factory pattern
- `dummy-vault`: Example vault implementation for testing
- All vaults share same contract address with object-based storage
- **Security**: Ownership validation and proper authorization checks
- **Flexibility**: External dispatch setup via ConstructorRef return

## Core Implementation: `packages/vault-core/sources/vault_token.move`

**Complete Function Set:**

```move
// Core Operations
create_vault(sender, underlying_token, custom_functions...) - Factory with function value customization
deposit(sender, underlying_token: FungibleAsset, vault_token) → FungibleAsset - Floor rounding
mint(sender, underlying_store: Object<FungibleStore>, vault_token, shares) → FungibleAsset - Ceil rounding
withdraw(sender, vault_store: Object<FungibleStore>, assets) → FungibleAsset - Ceil rounding
redeem(sender, vault_token: FungibleAsset) → FungibleAsset - Floor rounding

// View Functions
convert_to_shares(vault_token, assets) → u64 - Conversion utilities
convert_to_assets(vault_token, shares) → u64 - Conversion utilities
max_*() / preview_*() - Limits and previews with custom logic
asset(vault_token) → Object<Metadata> - Get underlying token
total_assets(vault_token) → u64 - Total underlying assets in vault
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

**Test Vault Integration:**

```bash
cd packages/dummy-vault
./sh_scripts/deploy.sh     # Deploy example vault
./sh_scripts/test.sh       # Test vault operations
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
- `ERR_EXCEEDED_MAX_REDEEM: u64 = 5`
- `ERR_NOT_STORE_OWNER: u64 = 6` - **NEW**: Ownership validation for operations

## Key Files for Development

- `packages/vault-core/sources/vault_token.move` - Main ERC-4626 implementation
- `packages/dummy-vault/sources/dummy_vault.move` - Example vault integration
- `packages/vault-core/contract_address.txt` - Core contract deploy address
- `packages/*/sh_scripts/` - All development commands
- `SECURITY_AUDIT_REPORT.md` - Comprehensive security audit
- `SECURITY_AUDIT_UPDATE.md` - Security fixes confirmation

## Recent Security Improvements

**Critical Fixes Applied (ef7ef5d):**
- ✅ Removed dispatch function security vulnerabilities
- ✅ Added ownership validation to mint() and withdraw() 
- ✅ Clean architecture with ConstructorRef pattern
- ✅ All authorization checks implemented properly

**Current Security Status:** 🟢 **SECURE** - Ready for testnet deployment
