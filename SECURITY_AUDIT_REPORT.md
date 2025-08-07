# ERC-4626 Vault Security Audit Report

**Date:** 2025-01-08  
**Auditor:** Claude Code AI  
**Project:** Aptos ERC-4626 Vault Implementation  
**Version:** Latest commit (df5ad8f)  
**Files Audited:** `packages/vault-core/sources/vault_token.move`

---

## Executive Summary

This audit examined the Aptos-based ERC-4626 vault implementation against the OpenZeppelin reference standard. The audit identified **2 critical security vulnerabilities** and **multiple compliance violations** that must be addressed before any production deployment.

**Overall Risk Assessment: 🔴 HIGH RISK**

### Key Findings

- ✅ **Strengths**: Solid architectural foundation, correct rounding strategies, inflation protection
- ❌ **Critical Issues**: 2 severe security vulnerabilities requiring immediate attention
- ⚠️ **Compliance**: Multiple ERC-4626 standard violations affecting interoperability

---

## Critical Security Vulnerabilities

### 🚨 CRITICAL-001: Dispatch Function Security Breach

**File:** `vault_token.move:149-160`  
**Severity:** Critical  
**Risk:** Complete contract failure, arbitrary code execution

**Issue:**

```move
let custom_withdraw = function_info::new_function_info(
    sender,  // ❌ WRONG! Uses sender address instead of module address
    string::utf8(b"vault_token"),
    string::utf8(b"custom_withdraw")
);
```

**Impact:**

- Dispatch functions registered under user's address instead of module address
- Runtime failures when vault operations attempt to call dispatch functions
- Potential for arbitrary function injection by malicious users
- Complete breakdown of vault functionality

**Recommendation:**
Replace `sender` with `@vault_core_addr` in both custom_withdraw and custom_deposit function registrations.

### 🚨 CRITICAL-002: Withdraw Authorization Vulnerability

**File:** `vault_token.move:329`  
**Severity:** Critical  
**Risk:** Unauthorized asset theft

**Issue:**

```move
public fun withdraw(
    sender: &signer, vault_store: Object<FungibleStore>, assets: u64
) {
    // ...
    fungible_asset::burn_from(&vault_controller.burn_ref, vault_store, shares);
    //                                                     ^^^^^^^^^^
    //                                        Burns from arbitrary store!
}
```

**Impact:**

- Function burns shares from any provided `vault_store` without owner validation
- Attacker can burn other users' shares by providing their store address
- Direct path to unauthorized asset withdrawal

**Recommendation:**
Implement proper owner validation or redesign to use sender's primary store only.

---

## ERC-4626 Compliance Violations

### ❌ VIOLATION-001: Missing Receiver Parameters

**Files:** All core functions  
**Severity:** High  
**Standard:** ERC-4626 requires receiver parameter separation

**Issue:**
All core functions missing proper `receiver` parameters as required by ERC-4626 standard:

```solidity
// ERC-4626 Standard
function deposit(uint256 assets, address receiver) returns (uint256 shares)
function mint(uint256 shares, address receiver) returns (uint256 assets)

// Current Implementation (Missing receiver)
public fun deposit(sender: &signer, underlying_token: FungibleAsset, vault_token: Object<Metadata>)
public fun mint(sender: &signer, underlying_store: Object<FungibleStore>, vault_token: Object<Metadata>, shares: u64)
```

**Impact:**

- Breaks DeFi composability
- Cannot integrate with standard ERC-4626 interfaces
- Limits protocol interoperability

### ❌ VIOLATION-002: Missing Owner Parameters

**Files:** `withdraw()`, `redeem()` functions  
**Severity:** High  
**Standard:** ERC-4626 owner/receiver separation

**Issue:**

```solidity
// ERC-4626 Standard
function withdraw(uint256 assets, address receiver, address owner) returns (uint256 shares)
function redeem(uint256 shares, address receiver, address owner) returns (uint256 assets)

// Current Implementation (Missing owner parameter)
public fun withdraw(sender: &signer, vault_store: Object<FungibleStore>, assets: u64)
public fun redeem(sender: &signer, vault_token: FungibleAsset)
```

**Impact:**

- Cannot support delegation patterns
- Breaks standard vault interfaces
- Limits advanced DeFi use cases

### ❌ VIOLATION-003: Incomplete Event Schema

**Files:** All event structures  
**Severity:** Medium  
**Standard:** ERC-4626 event requirements

**Issue:**
Events missing required `receiver` and `owner` fields:

```move
// Current Events
struct VaultDepositEvent {
    sender: address,          // ✅
    vault_token: Object<Metadata>,
    underlying_token: Object<Metadata>,
    assets: u64,             // ✅
    shares: u64              // ✅
    // ❌ Missing: receiver field
}
```

**Impact:**

- Incomplete audit trails
- Breaks event-based integrations
- Non-standard behavior for dApps

---

## Technical Implementation Issues

### ⚠️ ISSUE-001: State Update Sequence

**File:** `vault_token.move:251`  
**Severity:** Medium  
**Risk:** Potential inconsistent state

**Issue:**
In deposit function, state updated before share calculation completion:

```move
primary_fungible_store::deposit(vault_addr, underlying_token);
vault_state.underlying_total_amount += underlying_assets;  // ⚠️ Updated too early
let shares = preview_deposit(vault_token, underlying_assets);
```

**Recommendation:**
Move state updates after all operations complete successfully.

### ⚠️ ISSUE-002: Empty Vault Edge Case

**File:** `vault_token.move:567-568`  
**Severity:** Low  
**Risk:** Incorrect share calculation

**Issue:**

```move
if (total_assets == 0) {
    return assets;  // ⚠️ Should consider total supply too
};
```

**Impact:**
May not handle initial vault state correctly when total_assets = 0 but shares exist.

---

## Positive Findings

### ✅ Correct Implementations

1. **Rounding Strategies**: Perfect alignment with OpenZeppelin

   - Deposit: Floor (user-favorable) ✅
   - Mint: Ceil (protocol-favorable) ✅
   - Withdraw: Ceil (protocol-favorable) ✅
   - Redeem: Floor (user-favorable) ✅

2. **Inflation Protection**: Virtual assets/shares implemented correctly

   ```move
   let virtual_assets = 1;
   let virtual_shares = 1;
   ```

3. **Math Operations**: Proper mul_div with overflow protection

4. **Max Functions**: Correct logic for deposit/mint/withdraw/redeem limits

5. **Function Value System**: Innovative customization approach for Aptos

---

## Recommendations

### Immediate Actions Required

1. **🚨 Fix dispatch function addresses** - Replace `sender` with `@vault_core_addr`
2. **🚨 Fix withdraw authorization** - Implement proper owner validation
3. **📋 Add receiver parameters** to all core functions
4. **📋 Add owner parameters** to withdraw/redeem functions
5. **📊 Update event schemas** with missing fields

### Architectural Improvements

1. **Access Control**: Implement comprehensive authorization checks
2. **Parameter Validation**: Add bounds checking for all inputs
3. **Error Messages**: Enhance error codes with descriptive messages
4. **Testing**: Develop comprehensive test suite covering edge cases

### Long-term Enhancements

1. **Pausability**: Add emergency pause functionality
2. **Upgradability**: Consider upgrade patterns for future improvements
3. **Fee System**: Implement management/performance fees if required
4. **Multi-Asset**: Consider extending to support multiple underlying assets

---

## Risk Assessment Matrix

| Issue                    | Severity | Likelihood | Impact   | Priority |
| ------------------------ | -------- | ---------- | -------- | -------- |
| Dispatch Function Breach | Critical | High       | Critical | P0       |
| Withdraw Authorization   | Critical | High       | Critical | P0       |
| Missing Receiver Params  | High     | Medium     | High     | P1       |
| Missing Owner Params     | High     | Medium     | High     | P1       |
| Event Schema Issues      | Medium   | Low        | Medium   | P2       |
| State Update Timing      | Medium   | Low        | Medium   | P2       |

---

## Conclusion

The Aptos ERC-4626 vault implementation demonstrates solid understanding of the standard's mathematical requirements and implements correct rounding strategies. However, **critical security vulnerabilities prevent safe deployment** in the current state.

**Key Actions:**

1. ⛔ **DO NOT DEPLOY** until critical issues are resolved
2. 🛠️ **Implement security fixes** immediately
3. 📋 **Address ERC-4626 compliance** for interoperability
4. 🧪 **Conduct comprehensive testing** after fixes

The architectural foundation is strong and the innovative use of Move's function values shows promise. With proper security fixes, this could become a robust DeFi primitive on Aptos.

---

**Audit Methodology:** Manual code review against OpenZeppelin ERC-4626 reference implementation, security best practices analysis, and ERC-4626 standard compliance verification.

**Disclaimer:** This audit represents a point-in-time assessment. Continuous security practices and regular audits are recommended for production systems.
