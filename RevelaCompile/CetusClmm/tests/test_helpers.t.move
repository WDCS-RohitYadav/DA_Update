#[test_only]
module dexlyn_clmm::test_helpers {
    use std::signer;
    use std::string::{String, utf8, Self};
    use supra_framework::coin;
    use supra_framework::supra_account;

    struct TestCoinA has store, copy, drop {}
    struct TestCoinB has store, copy, drop {}

    #[test_only]
    public fun mint_tokens(admin: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<TestCoinA>(
            admin,
            string::utf8(b"TestCoin1"),
            string::utf8(b"TC1"),
            6,
            false
        );

        let (burn_cap1, freeze_cap1, mint_cap1) = coin::initialize<TestCoinB>(
            admin,
            string::utf8(b"TestCoin2"),
            string::utf8(b"TC2"),
            6,
            false
        );
        
        if (!coin::is_account_registered<TestCoinA>(signer::address_of(admin))) {
            coin::register<TestCoinA>(admin);
        };
        if (!coin::is_account_registered<TestCoinB>(signer::address_of(admin))) {
            coin::register<TestCoinB>(admin);
        };

        let mint_amount_a = 100000000;
        let mint_amount_b = 100000000;
        let decimals = 1000000;

        supra_account::deposit_coins<TestCoinA>(
            signer::address_of(admin),
            coin::mint<TestCoinA>(mint_amount_a * decimals, &mint_cap)
        );

        supra_account::deposit_coins<TestCoinB>(
            signer::address_of(admin),
            coin::mint<TestCoinB>(mint_amount_b * decimals, &mint_cap1)
        );

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);

        coin::destroy_burn_cap(burn_cap1);
        coin::destroy_mint_cap(mint_cap1);
        coin::destroy_freeze_cap(freeze_cap1);
    }
}
