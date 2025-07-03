#[test_only]
module dexlyn_clmm::fees_test {
    use std::signer;
    use std::string;

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::timestamp;

    use dexlyn_clmm::clmm_router::{
        add_fee_tier,
        add_liquidity,
        add_liquidity_fix_token,
        collect_fee,
        collect_protocol_fee,
        remove_liquidity,
        swap
    };
    use dexlyn_clmm::factory;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::test_helpers::{
        mint_tokens,
        TestCoinA,
        TestCoinB
    };
    use dexlyn_clmm::tick_math;

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_swap_fees_distribution(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);
        factory::init_factory_module(admin);

        let tick_spacing = 200;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 1000000;
        let amount_b = 1000000;
        let fix_a = true;
        let tick_lower = 18446744073709541616; // -10000
        let tick_upper = 10000;
        let is_new_position = true;

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
            amount_a,
            amount_b,
            fix_a,
            tick_lower,
            tick_upper,
            is_new_position,
            0
        );

        let user_balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));
        // Swap A->B
        let a2b = true;
        let exact_input = true;
        let amount = 100000;
        let min_or_max = 0;
        let price_limit = tick_math::min_sqrt_price() + 1;
        let referral = string::utf8(b"");
        swap<TestCoinA, TestCoinB>(admin, pool_address, a2b, exact_input, amount, min_or_max, price_limit, referral);

        let calculated_result = pool::calculate_swap_result<TestCoinA, TestCoinB>(
            pool_address,
            a2b,
            exact_input,
            amount
        );
        // actual fee amount after swap
        // fee amount = swapamount * fee_rate / 1000000 
        //            = 100000 * 1000 / 1000000 = 100


        let user_balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));
        assert!(user_balance_b_after > user_balance_b_before, 100);

        // Collect LP fees
        let fee_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let fee_b_before = coin::balance<TestCoinB>(signer::address_of(admin));
        collect_fee<TestCoinA, TestCoinB>(admin, pool_address, 1);

        // LP fee collection = fee amount - protocol fee= 100 - 20 = 80

        let fee_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let fee_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        let lp_collect_fees = fee_a_after - fee_a_before;
        assert!(lp_collect_fees == 79, 101); // 80

        // Protocol fee collection = fee amount * protocol_fee_rate / 10000
        //                         = 100 * 2000 / 10000 = 20
        collect_protocol_fee<TestCoinA, TestCoinB>(admin, pool_address);

        let protocol_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let protocol_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        let protocol_fees = protocol_a_after - fee_a_after;
        assert!(protocol_fees == 20, 102);
    }

    // LP fee collection after partial and full withdrawal
    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_lp_fee_collection_on_withdraw(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);

        let tick_spacing = 1;
        let init_sqrt_price = 18446744073709551616;
        let amount_a = 1000000;
        let amount_b = 1000000;
        let fix_a = true;
        let tick_lower = 18446744073709541616; // -10000
        let tick_upper = 10000;
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
            2541592,
            amount_a,
            amount_b,
            tick_lower,
            tick_upper,
            is_new_position,
            0
        );

        let a2b = true;
        let exact_input = true;
        let amount = 100000;
        let min_or_max = 0;
        let price_limit = tick_math::min_sqrt_price() + 1;
        let referral = string::utf8(b"");
        swap<TestCoinA, TestCoinB>(admin, pool_address, a2b, exact_input, amount, min_or_max, price_limit, referral);

        let balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));

        remove_liquidity<TestCoinA, TestCoinB>(
            admin,
            pool_address,
            2541592,
            0,
            0,
            1,
            true
        ); // remove liquidity with fees

        let balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        assert!(balance_a_after - balance_a_before > amount_a, 103); // balance will have: deposited liquidity + fees
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_no_swap_no_fees(admin: &signer, supra_framework: &signer) {
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
        add_liquidity_fix_token<TestCoinA, TestCoinB>(admin, pool_address, 1000000, 1000000, true, 0, 10000, true, 0);

        let balance_a_before = coin::balance<TestCoinA>(signer::address_of(admin));
        let balance_b_before = coin::balance<TestCoinB>(signer::address_of(admin));

        collect_fee<TestCoinA, TestCoinB>(admin, pool_address, 1);

        let balance_a_after = coin::balance<TestCoinA>(signer::address_of(admin));
        let balance_b_after = coin::balance<TestCoinB>(signer::address_of(admin));

        assert!(balance_a_after == balance_a_before && balance_b_after == balance_b_before, 105); // No fees accrued
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 22)] // E_POSITION_NOT_FOUND
    public entry fun test_collect_fee_position_not_found(admin: &signer, supra_framework: &signer) {
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

        collect_fee<TestCoinA, TestCoinB>(admin, pool_address, 99); // position doesn't exist
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    public entry fun test_protocol_fee_claim_zero(admin: &signer, supra_framework: &signer) {
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

        let before_a = coin::balance<TestCoinA>(signer::address_of(admin));
        let before_b = coin::balance<TestCoinB>(signer::address_of(admin));

        collect_protocol_fee<TestCoinA, TestCoinB>(admin, pool_address);

        let after_a = coin::balance<TestCoinA>(signer::address_of(admin));
        let after_b = coin::balance<TestCoinB>(signer::address_of(admin));
        assert!(after_a == before_a && after_b == before_b, 9001); // No protocol fees accrued
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm, user= @0x123
    )]
    #[expected_failure(abort_code = 1)] // E_NOT_AUTHORIZED
    public entry fun test_collect_protocol_fee_not_authorized(admin: &signer, user: &signer, supra_framework: &signer) {
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

        collect_protocol_fee<TestCoinA, TestCoinB>(user, pool_address);
    }

    #[test(
        supra_framework = @supra_framework,
        admin = @dexlyn_clmm,
    )]
    #[expected_failure(abort_code = 3)] // E_FEE_RATE_TOO_HIGH
    public entry fun test_add_fee_tier_too_high(admin: &signer, supra_framework: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        timestamp::set_time_has_started_for_testing(supra_framework);
        mint_tokens(admin);
        factory::init_factory_module(admin);
        let tick_spacing = 200;

        add_fee_tier(admin, tick_spacing, 999999);
    }
}
