#[test_only]
module vault_core_addr::test_end_to_end {
    use std::signer;
    use std::string;

    use aptos_framework::object;
    use aptos_framework::primary_fungible_store;
    use aptos_framework::option;

    use vault_core_addr::vault_token;

    #[test(
        aptos_framework = @aptos_framework, deployer = @vault_core_addr, sender = @0x100
    )]
    fun test_end_to_end(
        aptos_framework: &signer, deployer: &signer, sender: &signer
    ) {
        let sender_addr = signer::address_of(sender);
        let dummy_fa_constructor_ref = &object::create_sticky_object(sender_addr);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            dummy_fa_constructor_ref,
            option::none(),
            string::utf8(b"Dummy Token"),
            string::utf8(b"DTK"),
            6,
            string::utf8(b"icon_url"),
            string::utf8(b"project_url")
        );
        let dummy_fa = object::object_from_constructor_ref(dummy_fa_constructor_ref);

        let _vault_constructor_ref =
            vault_token::create_vault(
                sender,
                dummy_fa,
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none(),
                option::none()
            );
    }

    #[
        test(
            aptos_framework = @aptos_framework,
            deployer = @vault_core_addr,
            sender1 = @0x100,
            sender2 = @0x101
        )
    ]
    // #[expected_failure(abort_code = 1, location = vault_core_addr::vault_token)]
    fun test_expected_failure(
        aptos_framework: &signer,
        deployer: &signer,
        sender1: &signer,
        sender2: &signer
    ) {}
}
