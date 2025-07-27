module vault_core_addr::vault_token {
    use std::signer;
    use std::string::{Self, String};
    use std::math64;

    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_framework::fungible_asset::{Self, Metadata, TransferRef, MintRef, BurnRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::option::{Self, Option};
    use aptos_framework::string_utils;

    /// Underlying token mismatch
    const ERR_UNDERLYING_TOKEN_MISMATCH: u64 = 1;
    /// Exceeded max deposit
    const ERR_EXCEEDED_MAX_DEPOSIT: u64 = 2;

    const MAX_U64: u64 = 18446744073709551615;

    enum Rounding has drop {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    struct VaultState has key {
        underlying_token: Object<Metadata>,
        total_underlying: u64
    }

    struct VaultFunctions has key, store {
        convert_to_assets: |Object<Metadata>, u64| u64 has store + copy + drop,
        convert_to_shares: |Object<Metadata>, u64| u64 has store + copy + drop,
        preview_deposit: |Object<Metadata>, u64| u64 has store + copy + drop,
        preview_mint: |Object<Metadata>, u64| u64 has store + copy + drop,
        preview_withdraw: |Object<Metadata>, u64| u64 has store + copy + drop,
        preview_redeem: |Object<Metadata>, u64| u64 has store + copy + drop,
        max_deposit: |Object<Metadata>, address| u64 has store + copy + drop,
        max_mint: |Object<Metadata>, address| u64 has store + copy + drop,
        max_withdraw: |Object<Metadata>, address| u64 has store + copy + drop,
        max_redeem: |Object<Metadata>, address| u64 has store + copy + drop
    }

    struct VaultController has key {
        extend_ref: ExtendRef,
        transfer_ref: TransferRef,
        mint_ref: MintRef,
        burn_ref: BurnRef
    }

    #[event]
    struct CreateVaultEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>
    }

    #[event]
    struct DepositEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>,
        assets: u64,
        shares: u64
    }

    #[event]
    struct WithdrawEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>,
        assets: u64,
        shares: u64
    }

    // This function is only called once when the module is published for the first time.
    // init_module is optional, you can also have an entry function as the initializer.
    fun init_module(_sender: &signer) {}

    // ======================== Write functions ========================

    public fun create_vault(
        sender: &signer,
        underlying_token: Object<Metadata>,
        custom_convert_to_assets: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_convert_to_shares: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_preview_deposit: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_preview_mint: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_preview_withdraw: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_preview_redeem: Option<|Object<Metadata>, u64| u64 has store + copy + drop>,
        custom_max_deposit: Option<|Object<Metadata>, address| u64 has store + copy + drop>,
        custom_max_mint: Option<|Object<Metadata>, address| u64 has store + copy + drop>,
        custom_max_withdraw: Option<|Object<Metadata>, address| u64 has store + copy + drop>,
        custom_max_redeem: Option<|Object<Metadata>, address| u64 has store + copy + drop>
    ) {
        let vault_token_constructor_ref = &object::create_object(@vault_core_addr);
        let vault_token_signer = &object::generate_signer(vault_token_constructor_ref);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            vault_token_constructor_ref,
            option::none(),
            string_utils::format1(&b"vault_{}", fungible_asset::name(underlying_token)),
            string_utils::format1(&b"v{}", fungible_asset::symbol(underlying_token)),
            6,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url")
        );
        move_to(
            vault_token_signer,
            VaultState { underlying_token, total_underlying: 0 }
        );
        move_to(
            vault_token_signer,
            VaultFunctions {
                convert_to_assets: *custom_convert_to_assets.borrow_with_default(
                    &default_convert_to_assets
                ),
                convert_to_shares: *custom_convert_to_shares.borrow_with_default(
                    &default_convert_to_shares
                ),
                preview_deposit: *custom_preview_deposit.borrow_with_default(
                    &default_preview_deposit
                ),
                preview_mint: *custom_preview_mint.borrow_with_default(
                    &default_preview_mint
                ),
                preview_withdraw: *custom_preview_withdraw.borrow_with_default(
                    &default_preview_withdraw
                ),
                preview_redeem: *custom_preview_redeem.borrow_with_default(
                    &default_preview_redeem
                ),
                max_deposit: *custom_max_deposit.borrow_with_default(&default_max_deposit),
                max_mint: *custom_max_mint.borrow_with_default(&default_max_mint),
                max_withdraw: *custom_max_withdraw.borrow_with_default(
                    &default_max_withdraw
                ),
                max_redeem: *custom_max_redeem.borrow_with_default(&default_max_redeem)
            }
        );
        move_to(
            vault_token_signer,
            VaultController {
                extend_ref: object::generate_extend_ref(vault_token_constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(
                    vault_token_constructor_ref
                ),
                mint_ref: fungible_asset::generate_mint_ref(vault_token_constructor_ref),
                burn_ref: fungible_asset::generate_burn_ref(vault_token_constructor_ref)
            }
        );

        event::emit(
            CreateVaultEvent {
                sender: signer::address_of(sender), 
                vault_token: object::object_from_constructor_ref(
                    vault_token_constructor_ref
                ),
                underlying_token
            }
        );
    }

    public fun deposit(
        sender: &signer,
        underlying_token: Object<Metadata>,
        vault_token: Object<Metadata>,
        assets: u64
    ): u64 acquires VaultState, VaultFunctions, VaultController {
        let sender_addr = signer::address_of(sender);
        let vault_addr = object::object_address(&vault_token);
        let vault_state = borrow_global_mut<VaultState>(vault_addr);
        assert_underlying_token_is_matched(underlying_token, vault_state);

        let max_assets = max_deposit(vault_token, sender_addr);
        assert!(assets <= max_assets, ERR_EXCEEDED_MAX_DEPOSIT);

        primary_fungible_store::transfer(sender, underlying_token, vault_addr, assets);
        vault_state.total_underlying += assets;

        let shares = preview_deposit(vault_token, assets);
        let vault_controller =
            borrow_global<VaultController>(object::object_address(&vault_token));
        fungible_asset::mint_to(
            &vault_controller.mint_ref,
            primary_fungible_store::ensure_primary_store_exists(
                sender_addr, vault_token
            ),
            shares
        );

        event::emit(
            DepositEvent {
                sender: sender_addr,
                vault_token,
                underlying_token,
                assets,
                shares
            }
        );

        shares
    }

    public fun mint(sender: &signer, shares: u64) {
        abort 0
    }

    public fun withdraw(sender: &signer, shares: u64) {
        abort 0
    }

    public fun redeem(sender: &signer, shares: u64) {
        abort 0
    }

    // ======================== Read Functions ========================

    #[view]
    public fun asset(vault_token: Object<Metadata>): Object<Metadata> acquires VaultState {
        let vault_state = borrow_global<VaultState>(object::object_address(&vault_token));
        vault_state.underlying_token
    }

    #[view]
    public fun total_assets(vault_token: Object<Metadata>): u64 acquires VaultState {
        let vault_state = borrow_global<VaultState>(object::object_address(&vault_token));
        vault_state.total_underlying
    }

    #[view]
    public fun convert_to_shares(
        vault_token: Object<Metadata>, amount: u64
    ): u64 {
        abort 0
    }

    #[view]
    public fun convert_to_assets(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        abort 0
    }

    #[view]
    public fun max_deposit(vault_token: Object<Metadata>, owner: address): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.max_deposit) (vault_token, owner)
    }

    #[view]
    public fun preview_deposit(
        vault_token: Object<Metadata>, amount: u64
    ): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.preview_deposit) (vault_token, amount)
    }

    #[view]
    public fun max_mint(vault_token: Object<Metadata>): u64 {
        abort 0
    }

    #[view]
    public fun preview_mint(vault_token: Object<Metadata>, amount: u64): u64 {
        abort 0
    }

    #[view]
    public fun max_withdraw(vault_token: Object<Metadata>, shares: u64): u64 {
        abort 0
    }

    #[view]
    public fun preview_withdraw(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        abort 0
    }

    #[view]
    public fun max_redeem(vault_token: Object<Metadata>): u64 {
        abort 0
    }

    #[view]
    public fun preview_redeem(vault_token: Object<Metadata>, shares: u64): u64 {
        abort 0
    }

    // ========================= Default Implementations ========================= //

    public fun default_convert_to_shares(
        vault_token: Object<Metadata>, assets: u64
    ): u64 {
        convert_to_shares_internal(vault_token, assets, Rounding::Floor)
    }

    public fun default_convert_to_assets(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        abort 0
    }

    public fun default_max_deposit(
        _vault_token: Object<Metadata>, _owner: address
    ): u64 {
        MAX_U64
    }

    public fun default_preview_deposit(
        vault_token: Object<Metadata>, assets: u64
    ): u64 {
        default_convert_to_shares(vault_token, assets)
    }

    public fun default_max_mint(
        vault_token: Object<Metadata>, owner: address
    ): u64 {
        abort 0
    }

    public fun default_preview_mint(
        vault_token: Object<Metadata>, assets: u64
    ): u64 {
        abort 0
    }

    public fun default_max_withdraw(
        vault_token: Object<Metadata>, owner: address
    ): u64 {
        abort 0
    }

    public fun default_preview_withdraw(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        abort 0
    }

    public fun default_max_redeem(
        vault_token: Object<Metadata>, owner: address
    ): u64 {
        abort 0
    }

    public fun default_preview_redeem(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        abort 0
    }

    // ========================= Helper ========================= //

    fun assert_underlying_token_is_matched(
        underlying_token: Object<Metadata>, vault_state: &VaultState
    ) {
        assert!(
            vault_state.underlying_token == underlying_token,
            ERR_UNDERLYING_TOKEN_MISMATCH
        );
    }

    fun convert_to_shares_internal(
        vault_token: Object<Metadata>, assets: u64, rounding: Rounding
    ): u64 acquires VaultState {
        let vault_state = borrow_global<VaultState>(object::object_address(&vault_token));
        let total_assets = vault_state.total_underlying;
        if (total_assets == 0) {
            return assets;
        };
        math64::mul_div(
            assets,
            *fungible_asset::supply(vault_token).borrow_with_default(&0) as u64,
            total_assets
        )
    }

    fun convert_to_assets_internal(
        vault_token: Object<Metadata>, shares: u64, rounding: Rounding
    ): u64 acquires VaultState {
        let vault_state = borrow_global<VaultState>(object::object_address(&vault_token));
        let total_assets = vault_state.total_underlying;
        if (total_assets == 0) {
            return shares;
        };
        math64::mul_div(
            shares,
            total_assets,
            *fungible_asset::supply(vault_token).borrow_with_default(&0) as u64
        )
    }

    // ========================= Unit Tests Helper ================================== //

    #[test_only]
    public fun init_module_for_test(
        aptos_framework: &signer, sender: &signer
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        init_module(sender);
    }
}

