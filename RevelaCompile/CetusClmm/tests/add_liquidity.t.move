#[test_only]
module dexlyn_clmm::add_liquidity_test {
    use std::signer;
    use std::string::Self;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router::{
        add_fee_tier,
        add_liquidity,
        add_liquidity_fix_token};
    use dexlyn_clmm::factory;
    use dexlyn_clmm::fee_tier::get_fee_rate;
    use dexlyn_clmm::pool::get_pool_liquidity;
    use dexlyn_clmm::test_helpers::{
        mint_tokens,
        TestCoinA,
        TestCoinB
    };

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_create_and_add_liquidity(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);

        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let uri = b"";
        let amount_a = 100000;
        let amount_b = 400000;
        let tick_lower = 18446744073709551216; // -400
        let tick_upper = 16000;
        let fee_rate = 1000;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, fee_rate);
        assert!(fee_rate == get_fee_rate(tick_spacing), 1001);

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 181602, 1002); // min[181602.549077, 20201666.612228]

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1003); // 99999.6976491452
        assert!((user_balance_b_before - user_balance_b_after) == 3596, 1004); // 3595.782535883948
    }

    // #[test(
    //     supra_framework = @supra_framework,
    //     admin = @dexlyn_clmm,
    //     user_a = @0xA,
    //     user_b = @0xB,
    // )]
    // public entry fun test_nft_transfer_and_close_position(
    //     user_a: &signer,
    //     user_b: &signer,
    //     supra_framework: &signer,
    //     admin: &signer
    // ) {
    //     // Setup: mint tokens to user_a
    //     account::create_account_for_test(signer::address_of(admin));
    //     account::create_account_for_test(signer::address_of(user_a));
    //     account::create_account_for_test(signer::address_of(user_b));
    //     timestamp::set_time_has_started_for_testing(supra_framework);
    //     mint_tokens(admin);
    //
    //     let tick_spacing = 200;
    //     let init_sqrt_price = 18446744073709551616;
    //     let amount_a = 100000;
    //     let amount_b = 400000;
    //     let tick_lower = 18446744073709551216; // -400
    //     let tick_upper = 16000;
    //     let fee_rate = 1000;
    //     let uri = b"";
    //
    //     factory::init_factory_module(admin);
    //     add_fee_tier(admin, tick_spacing, fee_rate);
    //     assert!(fee_rate == get_fee_rate(tick_spacing), 2001);
    //
    //     let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
    //         admin,
    //         tick_spacing,
    //         init_sqrt_price,
    //         string::utf8(b"")
    //     );
    //     let pool_index = dexlyn_clmm::pool::get_pool_index<TestCoinA, TestCoinB>(pool_address);
    //
    //     let position_index = 1;
    //     let collection = dexlyn_clmm::position_nft::collection_name<TestCoinA, TestCoinB>(tick_spacing);
    //     let nft_name = dexlyn_clmm::position_nft::position_name(pool_index, position_index);
    //     add_liquidity_fix_token<TestCoinA, TestCoinB>(
    //         admin,
    //         pool_address,
    //         amount_a,
    //         amount_b,
    //         true,
    //         tick_lower,
    //         tick_upper,
    //         true,
    //         0
    //     );
    //
    //     let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
    //     assert!(pool_liquidity == 181602, 2002); // min[181602.549077, 20201666.612228]
    //
    //     let nft_addr = aptos_token_objects::token::create_token_address(
    //         &signer::address_of(user_a),
    //         &collection,
    //         &nft_name
    //     );
    //     assert!(dexlyn_clmm::position_nft::exists_at(nft_addr), 2101);
    //
    //     aptos_token_objects::token::direct_transfer_script(
    //         user_a,
    //         user_b,
    //         pool_address,
    //         collection,
    //         nft_name,
    //         0,
    //         1
    //     );
    //
    //     let nft_addr_b = aptos_token_objects::token::create_token_address(
    //         &signer::address_of(user_b),
    //         &collection,
    //         &nft_name
    //     );
    //     assert!(!dexlyn_clmm::position_nft::exists_at(nft_addr), 2102);
    //     assert!(dexlyn_clmm::position_nft::exists_at(nft_addr_b), 2103);
    //
    //     remove_liquidity<TestCoinA, TestCoinB>(
    //         user_b,
    //         pool_address,
    //         181602,
    //         0,
    //         0,
    //         1,
    //         true
    //     );
    //
    //     let pool_liquidity2 = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
    //     assert!(pool_liquidity2 == 0, 2003);
    // }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_add_liquidity_full_range(admin: &signer, supra_framework: &signer) {
        let admin_addr = signer::address_of(admin);
        account::create_account_for_test(admin_addr);

        timestamp::set_time_has_started_for_testing(supra_framework);

        mint_tokens(admin);

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616;
        let uri = b"";
        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709107980; // -min_lower
        let tick_upper = 443636;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let user_balance_a_before = coin::balance<TestCoinA>(admin_addr);
        let user_balance_b_before = coin::balance<TestCoinB>(admin_addr);

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 100000, 1001); // min[100000.000023, 100000.000023]

        let user_balance_a_after = coin::balance<TestCoinA>(admin_addr);
        let user_balance_b_after = coin::balance<TestCoinB>(admin_addr);

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.9999767165
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.9999767165

        add_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            25000,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            true,
            1
        );
        let pool_liquidity2 = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity2 == 100000 + 25000, 1004);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_liquidity_below_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709549616; // -2000
        let tick_upper = 18446744073709550616; // -1000

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            false,
            tick_lower,
            tick_upper,
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 0, 1001); // one-side-liquidity

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 0, 1002);
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.98553585552
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_liquidity_above_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 16000;
        let tick_upper = 26000;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 0, 1001); // one-side-liquidity

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.3271327113
        assert!((user_balance_b_before - user_balance_b_after) == 0, 1003);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_multiple_overlapping_positions(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        // Position 1
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            false,
            18446744073709549616, // -2000
            0, // 0
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 0, 1001); // min[0.000000, 1050883.152001]

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 0, 1002);
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003);

        // Position 2
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            18446744073709550616, // -1000
            16000,
            true,
            0
        );

        let pool_liquidity2 = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity2 == 181602, 1004); // min[181602.549077, 2050516.626811]

        let user_balance_a_after2 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after2 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_after - user_balance_a_after2) == 100000, 1005); // 99999.6976491452
        assert!((user_balance_b_after - user_balance_b_after2) == 8857, 1006); // 8856.402217154447

        // Position 3
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            100000,
            100000,
            true,
            0,
            26000,
            true,
            0
        );

        let pool_liquidity3 = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity3 == 137466 + pool_liquidity2, 1007); // [137466.399379, 0]

        let user_balance_a_after3 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after3 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_after2 - user_balance_a_after3) == 100000, 1008);
        assert!((user_balance_b_after3 - user_balance_b_after2) == 0, 1009);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_narrow_range_position(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 2;
        let init_sqrt_price = 18446744073709551616;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709551596; // -20
        let tick_upper = 20;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            amount_a,
            amount_b,
            true,
            tick_lower,
            tick_upper,
            true,
            0
        );

        let pool_liquidity = get_pool_liquidity<TestCoinA, TestCoinB>(pool_address);
        assert!(pool_liquidity == 100055008, 1001); // min[ 100055008.249595, 200060003.999810 ]

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!((user_balance_a_before - user_balance_a_after) == 100000, 1002); // 99999.99975054196
        assert!((user_balance_b_before - user_balance_b_after) == 100000, 1003); // 99999.99975053998
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 23)] // E_INVALID_TICK_INDEX
    public entry fun test_invalid_tick_range(admin: &signer, supra_framework: &signer) {
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
            16000,
            0,
            true,
            0
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 6)] // E_TICK_INDEX_OUT_OF_RANGE
    public entry fun test_uninitialized_tick(admin: &signer, supra_framework: &signer) {
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
            18446744073709549616, // -2000
            18446744073709550616, // -1000
            true,
            0
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 2)] // E_AMOUNT_MISMATCH
    public entry fun test_insufficient_liquidity(admin: &signer, supra_framework: &signer) {
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

        // add liquidity with zero amounts
        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            0,
            0,
            true,
            0,
            16000,
            true,
            0
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 23)]
    public entry fun test_invalid_tick_spacing(admin: &signer, supra_framework: &signer) {
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
            100, // not aligned to tick spacing
            16000,
            true,
            0
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 65542)] // EINSUFFICIENT_BALANCE
    public entry fun test_invalid_token_amounts(admin: &signer, supra_framework: &signer) {
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
            18446744073709551615,
            18446744073709551615,
            true,
            0,
            16000,
            true,
            0
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 2)] // E_INVALID_SQRT_PRICE
    public entry fun test_invalid_sqrt_price(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 0;
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
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 3)]
    public entry fun test_invalid_fee_rate(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000000);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 524303)] // ERESOURCE_ACCCOUNT_EXISTS
    public entry fun test_create_pool_with_same_token_types(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));

        timestamp::set_time_has_started_for_testing(supra_framework);

        mint_tokens(admin);

        let tick_spacing = 2;
        let tick_spacing2 = 200;
        let init_sqrt_price = 18446744073709551616;
        let uri = b"";
        let amount_a = 100000;
        let amount_b = 100000;
        let tick_lower = 18446744073709107980; // -min_lower
        let tick_upper = 443636;

        factory::init_factory_module(admin);

        add_fee_tier(admin, tick_spacing, 1000);
        add_fee_tier(admin, tick_spacing2, 1000);
        factory::create_pool<TestCoinA, TestCoinB>(admin, tick_spacing, init_sqrt_price, string::utf8(b""));
        factory::create_pool<TestCoinA, TestCoinB>(admin, tick_spacing, init_sqrt_price, string::utf8(b""));
    }
}