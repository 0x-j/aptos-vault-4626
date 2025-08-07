module dummy_vault_addr::dummy_vault {
    use std::math64;

    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, FungibleAsset, Metadata, TransferRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::option;
    use aptos_framework::function_info;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::string;

    use vault_core_addr::vault_token;

    const MAX_U64: u64 = 18446744073709551615;

    enum Rounding has drop {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    struct VaultToken has key {
        vault_metadata: Object<Metadata>
    }

    // This function is only called once when the module is published for the first time.
    // init_module is optional, you can also have an entry function as the initializer.
    fun init_module(sender: &signer) {
        let vault_constructor_ref =
            vault_token::create_vault(
                sender,
                // todo: replace with actual underlying fungible asset
                object::address_to_object(@0xa),
                option::some(custom_convert_to_assets),
                option::some(custom_convert_to_shares),
                option::some(custom_preview_deposit),
                option::some(custom_preview_mint),
                option::some(custom_preview_withdraw),
                option::some(custom_preview_redeem),
                option::some(custom_max_deposit),
                option::some(custom_max_mint),
                option::some(custom_max_withdraw),
                option::some(custom_max_redeem)
            );

        move_to(
            sender,
            VaultToken {
                vault_metadata: object::object_from_constructor_ref(
                    &vault_constructor_ref
                )
            }
        );

        let custom_withdraw =
            function_info::new_function_info(
                sender,
                string::utf8(b"dummy_vault"),
                string::utf8(b"custom_withdraw")
            );
        let custom_deposit =
            function_info::new_function_info(
                sender,
                string::utf8(b"dummy_vault"),
                string::utf8(b"custom_deposit")
            );

        dispatchable_fungible_asset::register_dispatch_functions(
            &vault_constructor_ref,
            option::some(custom_withdraw),
            option::some(custom_deposit),
            option::none()
        );
    }

    // ======================== View Functions ========================

    #[view]
    public fun get_vault_metadata(): Object<Metadata> acquires VaultToken {
        let vault_token = borrow_global<VaultToken>(@dummy_vault_addr);
        vault_token.vault_metadata
    }

    // ======================== Dispatch FA Custom Overwrite ========================

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

    // ======================== Vault Custom Overwrite ========================

    public fun custom_convert_to_shares(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultToken {
        convert_to_shares_internal(vault_token, assets, Rounding::Floor)
    }

    public fun custom_convert_to_assets(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultToken {
        convert_to_assets_internal(vault_token, shares, Rounding::Floor)
    }

    public fun custom_max_deposit(
        _vault_token: Object<Metadata>, _owner: address
    ): u64 {
        MAX_U64
    }

    public fun custom_preview_deposit(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultToken {
        custom_convert_to_shares(vault_token, assets)
    }

    public fun custom_max_mint(
        _vault_token: Object<Metadata>, _owner: address
    ): u64 {
        MAX_U64
    }

    public fun custom_preview_mint(
        vault_token: Object<Metadata>, shares: u64
    ): u64 acquires VaultToken {
        convert_to_assets_internal(vault_token, shares, Rounding::Ceil)
    }

    public fun custom_max_withdraw(
        vault_token: Object<Metadata>, owner: address
    ): u64 acquires VaultToken {
        // Max withdraw is the assets equivalent of user's share balance
        let user_shares = primary_fungible_store::balance(owner, vault_token);
        convert_to_assets_internal(vault_token, user_shares, Rounding::Floor)
    }

    public fun custom_preview_withdraw(
        vault_token: Object<Metadata>, assets: u64
    ): u64 acquires VaultToken {
        convert_to_shares_internal(vault_token, assets, Rounding::Ceil)
    }

    public fun custom_max_redeem(
        vault_token: Object<Metadata>, owner: address
    ): u64 {
        // Max redeem is simply the user's share balance
        primary_fungible_store::balance(owner, vault_token)
    }

    public fun custom_preview_redeem(
        vault_token: Object<Metadata>, shares: u64
    ): u64 {
        convert_to_assets_internal(vault_token, shares, Rounding::Floor)
    }

    // ========================= Helper ========================= //

    fun convert_to_shares_internal(
        vault_token: Object<Metadata>, assets: u64, rounding: Rounding
    ): u64 acquires VaultToken {
        let total_assets = vault_token::total_assets(get_vault_metadata());

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
    ): u64 acquires VaultToken {
        let total_assets = vault_token::total_assets(get_vault_metadata());

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
    use aptos_framework::timestamp;

    #[test_only]
    public fun init_module_for_test(
        aptos_framework: &signer, sender: &signer
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        init_module(sender);
    }
}

