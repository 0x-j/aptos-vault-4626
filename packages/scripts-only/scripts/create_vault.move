script {
    use std::string;

    use aptos_framework::object;
    use aptos_framework::option;

    use vault_core_addr::vault_token;

    // This Move script runs atomically
    fun create_vault(sender: &signer) {
        let fa = object::address_to_object(@0xa);
        vault_token::create_vault(
            sender,
            fa,
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
}

