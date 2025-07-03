#[test_only]
module dexlyn_clmm::swap_test {
    use std::signer;
    use std::string::Self;
    use aptos_std::comparator::Self;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router::{
        add_fee_tier,
        add_liquidity_fix_token,
        pause_pool,
        swap
    };
    use dexlyn_clmm::factory;
    use dexlyn_clmm::test_helpers::{
        mint_tokens,
        TestCoinA,
        TestCoinB
    };
    use dexlyn_clmm::tick_math;
    use dexlyn_clmm::utils;

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_exact_input_below_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // sqrt price at tick 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 10000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 1000000;
        let amount_b = 1000000;
        let tick_lower = 18446744073709549616; // -2000
        let tick_upper = 18446744073709550616; // -1000
        
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

        let swap_amount = 10000;
        let min_output = 0;
        let atob = false;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        let result_compare = utils::compare_coin<TestCoinA, TestCoinB>();
        if (comparator::is_smaller_than(&result_compare)) {
            atob = true;
        } else {
            atob = false;
        };

        let price_limit: u128 = if (atob) {
            tick_math::min_sqrt_price() + 1
        }   else {
            tick_math::min_sqrt_price() - 1
        };

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true, // a2b
            true, // exact_input
            swap_amount,
            min_output,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 8954),
            2
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_exact_output_above_current_tick(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // sqrt price at tick 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 1000000;
        let amount_b = 1000000;
        let tick_lower = 1000;
        let tick_upper = 2000;
        let atob = false;

        let result_compare = utils::compare_coin<TestCoinA, TestCoinB>();
        if (comparator::is_smaller_than(&result_compare)) {
            atob = true;
        } else {
            atob = false;
        };

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

        // Perform exact output swap
        let swap_amount = 10000;
        let max_input = 1000000;

        let price_limit: u128 = if (!atob) { // to swap by amount b

            tick_math::min_sqrt_price() + 1
        }   else {
            tick_math::max_sqrt_price() - 1
        };

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            false,
            false,
            swap_amount,
            max_input,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before + swap_amount) && (user_balance_b_after == user_balance_b_before - 11070),
            2
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_with_price_limit(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // sqrt price at tick 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 1000000;
        let amount_b = 1000000;
        let tick_lower = 18446744073709550616; // -1000
        let tick_upper = 1000;
        let atob = false;

        let result_compare = utils::compare_coin<TestCoinA, TestCoinB>();
        if (comparator::is_smaller_than(&result_compare)) {
            atob = true;
        } else {
            atob = false;
        };

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

        let swap_amount = 10000;
        let min_output = 0;
        let price_limit = 17991314827363146364; // price at -500 tick

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            swap_amount,
            min_output,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 9985),
            1
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_edge_cases(admin: &signer, supra_framework: &signer) {
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

        // Add liquidity in full range
        let amount_a = 10000000000;
        let amount_b = 10000000000;
        let tick_lower = 18446744073709107980; // min tick
        let tick_upper = 443636; // max tick

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

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        // Very small swap amount
        let small_amount = 1;
        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            small_amount,
            0,
            tick_math::min_sqrt_price() + 1,
            string::utf8(b"")
        );

        let user_balance_a_after1 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after1 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after1 == user_balance_a_before - small_amount) && (user_balance_b_after1 == user_balance_b_before),
            1
        );

        // large swap amount
        let large_amount = 10000000000000;
        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            large_amount,
            0,
            tick_math::min_sqrt_price() + 1,
            string::utf8(b"")
        );

        let user_balance_a_after2 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after2 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(user_balance_a_after2 == user_balance_a_after1 - large_amount, 2);
        assert!(user_balance_b_after2 == user_balance_b_after1 + 9990000001, 2);

        // Swap in reverse direction
        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            false, // b2a
            true,
            10000,
            0,
            tick_math::max_sqrt_price() - 1,
            string::utf8(b"")
        );

        let user_balance_a_after3 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after3 = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(user_balance_a_after3 == user_balance_a_after2 + 9980029946, 2);
        assert!(user_balance_b_after3 == user_balance_b_after2 - 10000, 2);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_cross_tick_swap_single_position(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at tick 0
        factory::init_factory_module(admin);
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );

        let amount_a = 1000000;
        let amount_b = 1000000;
        let tick_lower = 18446744073709549616; // -2000
        let tick_upper = 2000;

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

        let swap_amount = 500000;
        let min_output = 0;
        let price_limit = tick_math::min_sqrt_price() + 1;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true, // a2b
            true, // exact_input
            swap_amount,
            min_output,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 476835),
            1
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_cross_tick_swap_multiple_positions(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at tick 0
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
            1000000,
            1000000,
            false,
            18446744073709549616, // -2000
            18446744073709550616, // -1000
            true,
            0
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1000000,
            1000000,
            false,
            18446744073709550616, // -1000
            0,
            true,
            1
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1000000,
            1000000,
            true,
            0,
            1000,
            true,
            2
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1000000,
            1000000,
            true,
            1000, // 1000
            2000, // 2000
            true,
            3
        );

        // Perform swap that crosses all positions
        let swap_amount = 2000000;
        let min_output = 0;
        let price_limit = tick_math::min_sqrt_price() + 1;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            swap_amount,
            min_output,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 1822287),
            1
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_cross_tick_swap_with_gaps(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616; // at tick 0
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
            1000000,
            1000000,
            false,
            18446744073709549616, // -2000
            18446744073709550616, // -1000
            true,
            0
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1000000,
            1000000,
            true,
            0,
            1000,
            true,
            1
        );

        add_liquidity_fix_token<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            1000000,
            1000000,
            true,
            2000,
            3000,
            true,
            2
        );

        let swap_amount = 150000;
        let min_output = 0;
        let price_limit = tick_math::min_sqrt_price() + 1;

        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            swap_amount,
            min_output,
            price_limit,
            string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 134699),
            1
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 24)] // E_POOL_PAUSED
    public entry fun test_swap_pool_paused(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);
        factory::init_factory_module(admin);
        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        add_fee_tier(admin, tick_spacing, 1000);
        let pool_address = factory::create_pool<TestCoinA, TestCoinB>(
            admin,
            tick_spacing,
            init_sqrt_price,
            string::utf8(b"")
        );
        add_liquidity_fix_token<TestCoinA, TestCoinB>(admin, pool_address, 100000, 100000, true, 0, 10000, true, 0);

        pause_pool<TestCoinA, TestCoinB>(admin, pool_address);

        swap<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            true,
            true,
            1000,
            0,
            tick_math::min_sqrt_price() + 1,
            string::utf8(b"")
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_b2a_direction(admin: &signer, supra_framework: &signer) {
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
            admin, pool_address, 100000000, 100000000, true, 0, 10000, true, 0
        );

        let small_swap = 10;
        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));
        swap<TestCoinA, TestCoinB>(
            admin, pool_address, false, true, small_swap, 0, tick_math::max_sqrt_price() - 1, string::utf8(b"")
        );
        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));
        assert!(
            (user_balance_a_after == user_balance_a_before + 8) && (user_balance_b_after == user_balance_b_before - small_swap),
            102
        );

        let large_swap = 10000000;
        swap<TestCoinA, TestCoinB>(
            admin, pool_address, false, true, large_swap, 0, tick_math::max_sqrt_price() - 1, string::utf8(b"")
        );
        let user_balance_a_after2 = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after2 = coin::balance<TestCoinB>(signer::address_of(admin));
        assert!(
            (user_balance_a_after2 == user_balance_a_after + 9612182) && (user_balance_b_after2 == user_balance_b_after - large_swap),
            103
        );
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_entire_liquidity(admin: &signer, supra_framework: &signer) {
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
            admin, pool_address, 100000, 100000, true, 18446744073709549616, 2000, true, 0
        );

        // Swap all liquidity
        let swap_amount = 100000;
        let user_balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));
        swap<TestCoinA, TestCoinB>(
            admin, pool_address, true, true, swap_amount, 0, tick_math::min_sqrt_price() + 1, string::utf8(b"")
        );

        let user_balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));
        assert!(
            (user_balance_a_after == user_balance_a_before - swap_amount) && (user_balance_b_after == user_balance_b_before + 91227),
            104
        );
    }
}
