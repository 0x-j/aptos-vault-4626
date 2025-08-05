module vault_core_addr::vault_token {
    use std::signer;
    use std::string::{Self, String};
    use std::math64;

    use aptos_framework::event;
    use aptos_framework::object::{Self, Object, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_framework::fungible_asset::{
        Self,
        FungibleAsset,
        Metadata,
        TransferRef,
        MintRef,
        BurnRef
    };
    use aptos_framework::primary_fungible_store;
    use aptos_framework::option::{Self, Option};
    use aptos_framework::string_utils;
    use aptos_framework::function_info;
    use aptos_framework::dispatchable_fungible_asset;

    /// Underlying token mismatch
    const ERR_UNDERLYING_TOKEN_MISMATCH: u64 = 1;
    /// Exceeded max deposit
    const ERR_EXCEEDED_MAX_DEPOSIT: u64 = 2;
    /// Exceeded max mint
    const ERR_EXCEEDED_MAX_MINT: u64 = 3;
    /// Exceeded max withdraw
    const ERR_EXCEEDED_MAX_WITHDRAW: u64 = 4;
    /// Insufficient shares
    const ERR_INSUFFICIENT_SHARES: u64 = 5;
    /// Exceeded max redeem
    const ERR_EXCEEDED_MAX_REDEEM: u64 = 6;

    const MAX_U64: u64 = 18446744073709551615;

    enum Rounding has drop {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    struct VaultState has key, store {
        underlying_token: Object<Metadata>,
        underlying_total_amount: u64
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

    struct VaultController has key, store {
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
    struct VaultDepositEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>,
        assets: u64,
        shares: u64
    }

    #[event]
    struct VaultWithdrawEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>,
        assets: u64,
        shares: u64
    }

    #[event]
    struct VaultMintEvent has store, drop {
        sender: address,
        vault_token: Object<Metadata>,
        underlying_token: Object<Metadata>,
        assets: u64,
        shares: u64
    }

    #[event]
    struct VaultRedeemEvent has store, drop {
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
            // todo: replace with actual metadata
            string_utils::format1(&b"vault_{}", fungible_asset::name(underlying_token)),
            string_utils::format1(&b"v{}", fungible_asset::symbol(underlying_token)),
            6,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url")
        );

        // Override the deposit and withdraw function
        let custom_withdraw =
            function_info::new_function_info(
                sender,
                string::utf8(b"vault_token"),
                string::utf8(b"custom_withdraw")
            );
        let custom_deposit =
            function_info::new_function_info(
                sender,
                string::utf8(b"vault_token"),
                string::utf8(b"custom_deposit")
            );

        dispatchable_fungible_asset::register_dispatch_functions(
            vault_token_constructor_ref,
            option::some(custom_withdraw),
            option::some(custom_deposit),
            option::none()
        );

        move_to(
            vault_token_signer,
            VaultState { underlying_token, underlying_total_amount: 0 }
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

    public fun custom_withdraw<T: key>(
        store: Object<T>, amount: u64, transfer_ref: &TransferRef
    ): FungibleAsset {
        fungible_asset::withdraw_with_ref(transfer_ref, store, amount)
    }

    public fun custom_deposit<T: key>(
        store: Object<T>, fa: FungibleAsset, transfer_ref: &TransferRef
    ) {
        fungible_asset::deposit_with_ref(transfer_ref, store, fa);
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
        vault_state.underlying_total_amount += assets;

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
            VaultDepositEvent {
                sender: sender_addr,
                vault_token,
                underlying_token,
                assets,
                shares
            }
        );

        shares
    }

    public fun mint(
        sender: &signer,
        underlying_token: Object<Metadata>,
        vault_token: Object<Metadata>,
        shares: u64
    ): u64 acquires VaultState, VaultFunctions, VaultController {
        let sender_addr = signer::address_of(sender);
        let vault_addr = object::object_address(&vault_token);
        let vault_state = borrow_global_mut<VaultState>(vault_addr);
        assert_underlying_token_is_matched(underlying_token, vault_state);

        let max_shares = max_mint(vault_token, sender_addr);
        assert!(shares <= max_shares, ERR_EXCEEDED_MAX_MINT);

        let assets = preview_mint(vault_token, shares);

        primary_fungible_store::transfer(sender, underlying_token, vault_addr, assets);
        vault_state.underlying_total_amount += assets;

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
            VaultMintEvent {
                sender: sender_addr,
                vault_token,
                underlying_token,
                assets,
                shares
            }
        );

        assets
    }

    public fun withdraw(
        sender: &signer,
        underlying_token: Object<Metadata>,
        vault_token: Object<Metadata>,
        assets: u64,
        receiver: address
    ): u64 acquires VaultState, VaultFunctions, VaultController {
        let sender_addr = signer::address_of(sender);
        let vault_addr = object::object_address(&vault_token);
        let vault_state = borrow_global_mut<VaultState>(vault_addr);
        assert_underlying_token_is_matched(underlying_token, vault_state);

        let max_assets = max_withdraw(vault_token, sender_addr);
        assert!(assets <= max_assets, ERR_EXCEEDED_MAX_WITHDRAW);

        let shares = preview_withdraw(vault_token, assets);

        // Check if sender has enough shares
        let sender_balance = primary_fungible_store::balance(sender_addr, vault_token);
        assert!(sender_balance >= shares, ERR_INSUFFICIENT_SHARES);

        // Burn shares from sender
        let vault_controller =
            borrow_global<VaultController>(object::object_address(&vault_token));
        fungible_asset::burn_from(
            &vault_controller.burn_ref,
            primary_fungible_store::primary_store(sender_addr, vault_token),
            shares
        );

        // Update vault state
        vault_state.underlying_total_amount -= assets;

        // Transfer assets to receiver
        let vault_signer =
            &object::generate_signer_for_extending(&vault_controller.extend_ref);
        primary_fungible_store::transfer(
            vault_signer,
            underlying_token,
            receiver,
            assets
        );

        event::emit(
            VaultWithdrawEvent {
                sender: sender_addr,
                vault_token,
                underlying_token,
                assets,
                shares
            }
        );

        shares
    }

    public fun redeem(
        sender: &signer,
        underlying_token: Object<Metadata>,
        vault_token: Object<Metadata>,
        shares: u64,
        receiver: address
    ): u64 acquires VaultState, VaultFunctions, VaultController {
        let sender_addr = signer::address_of(sender);
        let vault_addr = object::object_address(&vault_token);
        let vault_state = borrow_global_mut<VaultState>(vault_addr);
        assert_underlying_token_is_matched(underlying_token, vault_state);

        let max_shares = max_redeem(vault_token, sender_addr);
        assert!(shares <= max_shares, ERR_EXCEEDED_MAX_REDEEM);

        // Check if sender has enough shares
        let sender_balance = primary_fungible_store::balance(sender_addr, vault_token);
        assert!(sender_balance >= shares, ERR_INSUFFICIENT_SHARES);

        let assets = preview_redeem(vault_token, shares);

        // Burn shares from sender
        let vault_controller =
            borrow_global<VaultController>(object::object_address(&vault_token));
        fungible_asset::burn_from(
            &vault_controller.burn_ref,
            primary_fungible_store::primary_store(sender_addr, vault_token),
            shares
        );

        // Update vault state
        vault_state.underlying_total_amount -= assets;

        // Transfer assets to receiver
        let vault_signer =
            &object::generate_signer_for_extending(&vault_controller.extend_ref);
        primary_fungible_store::transfer(
            vault_signer,
            underlying_token,
            receiver,
            assets
        );

        event::emit(
            VaultRedeemEvent {
                sender: sender_addr,
                vault_token,
                underlying_token,
                assets,
                shares
            }
        );

        assets
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
        vault_state.underlying_total_amount
    }

    #[view]
    public fun convert_to_shares(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.convert_to_shares) (vault_token, assets)
    }

    #[view]
    public fun convert_to_assets(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.convert_to_assets) (vault_token, shares)
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
    public fun max_mint(vault_token: Object<Metadata>, owner: address): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.max_mint) (vault_token, owner)
    }

    #[view]
    public fun preview_mint(vault_token: Object<Metadata>, shares: u64): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.preview_mint) (vault_token, shares)
    }

    #[view]
    public fun max_withdraw(
        vault_token: Object<Metadata>, owner: address
    ): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.max_withdraw) (vault_token, owner)
    }

    #[view]
    public fun preview_withdraw(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.preview_withdraw) (vault_token, assets)
    }

    #[view]
    public fun max_redeem(vault_token: Object<Metadata>, owner: address): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.max_redeem) (vault_token, owner)
    }

    #[view]
    public fun preview_redeem(vault_token: Object<Metadata>, shares: u64): u64 acquires VaultFunctions {
        let vault_functions =
            borrow_global<VaultFunctions>(object::object_address(&vault_token));
        (vault_functions.preview_redeem) (vault_token, shares)
    }

    // ========================= Default Implementations ========================= //

    public fun default_convert_to_shares(
        vault_token: Object<Metadata>, assets: u64
    ): u64 {
        convert_to_shares_internal(vault_token, assets, Rounding::Floor)
    }

    public fun default_convert_to_assets(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultState {
        convert_to_assets_internal(vault_token, shares, Rounding::Floor)
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
        _vault_token: Object<Metadata>, _owner: address
    ): u64 {
        MAX_U64
    }

    public fun default_preview_mint(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultState {
        convert_to_assets_internal(vault_token, shares, Rounding::Ceil)
    }

    public fun default_max_withdraw(
        vault_token: Object<Metadata>, owner: address
    ): u64 acquires VaultState {
        // Max withdraw is the assets equivalent of user's share balance
        let user_shares = primary_fungible_store::balance(owner, vault_token);
        convert_to_assets_internal(vault_token, user_shares, Rounding::Floor)
    }

    public fun default_preview_withdraw(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultState {
        convert_to_shares_internal(vault_token, assets, Rounding::Ceil)
    }

    public fun default_max_redeem(
        vault_token: Object<Metadata>, owner: address
    ): u64 {
        // Max redeem is simply the user's share balance
        primary_fungible_store::balance(owner, vault_token)
    }

    public fun default_preview_redeem(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultState {
        convert_to_assets_internal(vault_token, shares, Rounding::Floor)
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
        let total_assets = vault_state.underlying_total_amount;
        if (total_assets == 0) {
            return assets;
        };

        // Add virtual assets/shares for inflation attack protection (like OpenZeppelin)
        let virtual_assets = 1;
        let virtual_shares = 1; // Could be 10^decimalsOffset like OpenZeppelin

        mul_div_with_rounding(
            assets,
            (*fungible_asset::supply(vault_token).borrow_with_default(&0) as u64)
                + virtual_shares,
            total_assets + virtual_assets,
            rounding
        )
    }

    fun convert_to_assets_internal(
        vault_token: Object<Metadata>, shares: u64, rounding: Rounding
    ): u64 acquires VaultState {
        let vault_state = borrow_global<VaultState>(object::object_address(&vault_token));
        let total_assets = vault_state.underlying_total_amount;
        if (total_assets == 0) {
            return shares;
        };

        let virtual_assets = 1;
        let virtual_shares = 1;
        mul_div_with_rounding(
            shares,
            total_assets + virtual_assets,
            (*fungible_asset::supply(vault_token).borrow_with_default(&0) as u64)
                + virtual_shares,
            rounding
        )
    }

    fun mul_div_with_rounding(
        a: u64, b: u64, c: u64, rounding: Rounding
    ): u64 {
        match(rounding) {
            Rounding::Floor => math64::mul_div(a, b, c),
            Rounding::Ceil => {
                let result = math64::mul_div(a, b, c);
                // Add 1 if there's a remainder
                if ((a * b) % c != 0) { result + 1 }
                else { result }
            },
            Rounding::Trunc => math64::mul_div(a, b, c), // Same as floor for positive numbers
            Rounding::Expand => {
                // Round away from zero - for positive numbers, same as ceil
                let result = math64::mul_div(a, b, c);
                if ((a * b) % c != 0) { result + 1 }
                else { result }
            }
        }
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

