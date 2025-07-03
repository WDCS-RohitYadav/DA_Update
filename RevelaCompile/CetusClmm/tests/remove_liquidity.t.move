#[test_only]
module dexlyn_clmm::remove_liquidity_test {
    use std::signer;
    use std::string::Self;
    use std::debug::print;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router::{
        add_fee_tier,
        add_liquidity,
        add_liquidity_fix_token,
        collect_fee,
        remove_liquidity
    };
    use dexlyn_clmm::factory;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::test_helpers::{
        mint_tokens,
        TestCoinA,
        TestCoinB
    };

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_remove_liquidity_basic(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 25000;
        let amount_b = 25000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 400;
        let is_new_position = true;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);

        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );


        add_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1262604,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            is_new_position,
            0
        );

        let pool_liquidity = pool::get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 1262604, 1002); // 1262604.163264

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        

        // Remove half of the liquidity
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            15000,
            0,
            0,
            1,
            false
        );

        let user_balance_a_after2 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after2 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(user_balance_a_after2 == user_balance_a_after + 297, 1003); // 297.0051983913116
        assert!(user_balance_b_after2 == user_balance_b_after + 297, 1004); // 297.005198391313
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_remove_liquidity_with_fees(admin: &signer, supra_framework: &signer) {
        // aptos_token_objects::initialize_token_store(admin);
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 2;
        let init_sqrt_price = 18539204128674405812; // 100
        let amount_a = 100000000;
        let amount_b = 100000000;
        let tick_lower = 0;
        let tick_upper = 16000;
        let is_new_position = true;


        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        add_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            183262358,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            is_new_position,
            0
        );

        let pool_liquidity = pool::get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 183262358, 1002); // min [ 183262358.680300, 19951041647.902805 ]

        // Collect fees first
        collect_fee<TestCoinA, TestCoinB>(admin, pool_address, 1);

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        // Remove liquidity
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            50000,
            10000,
            0,
            1,
            false
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(user_balance_a_after == user_balance_a_before + 27283, 1003); // 27283.28957460632
        assert!(user_balance_b_after == user_balance_b_before + 250, 1004); // 250.61348115252846
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_remove_liquidity_full_range(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616; // 0
        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709107980; // -min_lower
        let tick_upper = 443636;
        let is_new_position = true;

        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        add_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            is_new_position,
            0
        );

        let pool_liquidity = pool::get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 100000, 1002); // min [ 100000.000023, 100000.000023 ]

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        // Remove all liquidity
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            99999,
            99999,
            1,
            true
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(user_balance_a_after == user_balance_a_before + 99999, 1003); // 99999.9999767165
        assert!(user_balance_b_after == user_balance_b_before + 99999, 1004); // 99999.9999767165
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 7)] // E_ZERO_LIQUIDITY
    public entry fun test_remove_zero_liquidity(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            16000,
            true,
            0
        );

        // remove zero liquidity
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            0,
            0,
            0,
            0,
            false
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 4)] // E_LESS_THAN_MIN
    public entry fun test_remove_liquidity_insufficient_amounts(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            16000,
            true,
            0
        );

        // Try to remove with insufficient minimum amounts
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            0,
            1,
            false
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 22)] // E_POSITION_NOT_FOUND
    public entry fun test_remove_liquidity_invalid_position(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            999,
            12, // Invalid position index
            false
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_remove_liquidity_multiple_positions(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        // Add multiple positions
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            16000,
            true,
            0
        );

        let pool_liquidity = pool::get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 181602, 1001);

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            16000,
            32000,
            true,
            0
        );

        let pool_liquidity = pool::get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 181602, 1001); // one-side-liquidity

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        // Remove liquidity from first position
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            50000,
            0,
            0,
            1,
            false
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        // balance after first removal
        assert!(user_balance_a_after == user_balance_a_before + 27532, 1003); // 27532.65317814374
        assert!(user_balance_b_after == user_balance_b_before, 1004);

        // Remove liquidity from second position
        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            50000,
            0,
            0,
            2,
            false
        );


        let user_balance_a_after2 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after2 = coin::balance<TestCoinB>(signer::address_of(admin));

        // balance after second removal
        assert!(user_balance_a_after2 == user_balance_a_after + 12371, 1003);
        assert!(user_balance_b_after2 == user_balance_b_after, 1004);
    }
}
