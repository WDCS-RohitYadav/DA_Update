module dexlyn_clmm::clmm_router {

    use std::signer;
    use std::string::String;

    use supra_framework::coin;

    use dexlyn_clmm::config;
    use dexlyn_clmm::factory;
    use dexlyn_clmm::fee_tier;
    use dexlyn_clmm::partner;
    use dexlyn_clmm::pool;
    use integer_mate::i64;

    /// required amount A exceeds the maximum allowed value
    const E_EXCEED_MAX_A: u64 = 1;

    /// required amount B exceeds the maximum allowed value
    const E_EXCEED_MAX_B: u64 = 2;

    /// the pay amount exceeds the maximum allowed value
    const E_EXCEED_MAX_PAY_AMOUNT: u64 = 3;

    /// the received amount is less than the minimum required value
    const E_LESS_THAN_MIN: u64 = 4;

    /// the tick range does not match the expected range for a position
    const E_TICK_RANGE_MISMATCH: u64 = 5;

    /// the provided amount does not match the expected amount
    const E_AMOUNT_MISMATCH: u64 = 6;

    /// closing a position fails
    const E_CLOSE_POSITION_FAIL: u64 = 7;

    public entry fun swap<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        a2b: bool,
        exact_input: bool,
        amount: u64,
        min_or_max: u64,
        price_limit: u128,
        referral: String
    ) {
        let account_addr = signer::address_of(account);
        let (input_coin, output_coin, pool_state) = pool::flash_swap<CoinA, CoinB>(
            pool_address,
            account_addr,
            referral,
            a2b,
            exact_input,
            amount,
            price_limit
        );
        let pay_amount = pool::swap_pay_amount<CoinA, CoinB>(&pool_state);
        let receive_amount = if (a2b) {
            coin::value<CoinB>(&output_coin)
        } else {
            coin::value<CoinA>(&input_coin)
        };
        if (exact_input) {
            assert!(pay_amount == amount, E_AMOUNT_MISMATCH);
            assert!(receive_amount >= min_or_max, E_LESS_THAN_MIN);
        } else {
            assert!(receive_amount == amount, E_AMOUNT_MISMATCH);
            assert!(pay_amount <= min_or_max, E_EXCEED_MAX_PAY_AMOUNT);
        };
        if (a2b) {
            if (!coin::is_account_registered<CoinB>(account_addr)) {
                coin::register<CoinB>(account);
            };
            coin::destroy_zero<CoinA>(input_coin);
            coin::deposit<CoinB>(account_addr, output_coin);
            pool::repay_flash_swap<CoinA, CoinB>(
                coin::withdraw<CoinA>(account, pay_amount),
                coin::zero<CoinB>(),
                pool_state
            );
        } else {
            if (!coin::is_account_registered<CoinA>(account_addr)) {
                coin::register<CoinA>(account);
            };
            coin::destroy_zero<CoinB>(output_coin);
            coin::deposit<CoinA>(account_addr, input_coin);
            pool::repay_flash_swap<CoinA, CoinB>(
                coin::zero<CoinA>(),
                coin::withdraw<CoinB>(account, pay_amount),
                pool_state
            );
        };
    }

    public entry fun accept_protocol_authority(admin: &signer) {
        config::accept_protocol_authority(admin);
    }

    public entry fun add_role(admin: &signer, member: address, role: u8) {
        config::add_role(admin, member, role);
    }

    public entry fun init_clmm_acl(admin: &signer) {
        config::init_clmm_acl(admin);
    }

    public entry fun pause(admin: &signer) {
        config::pause(admin);
    }

    public entry fun remove_role(admin: &signer, member: address, role: u8) {
        config::remove_role(admin, member, role);
    }

    public entry fun transfer_protocol_authority(admin: &signer, member: address) {
        config::transfer_protocol_authority(admin, member);
    }

    public entry fun unpause(admin: &signer) {
        config::unpause(admin);
    }

    public entry fun update_pool_create_authority(admin: &signer, member: address) {
        config::update_pool_create_authority(admin, member);
    }

    public entry fun update_protocol_fee_claim_authority(admin: &signer, member: address) {
        config::update_protocol_fee_claim_authority(admin, member);
    }

    public entry fun update_protocol_fee_rate(admin: &signer, member: u64) {
        config::update_protocol_fee_rate(admin, member);
    }

    public entry fun create_pool<CoinA, CoinB>(
        account: &signer,
        tick_spacing: u64,
        init_sqrt_price: u128,
        uri: String
    ) {
        factory::create_pool<CoinA, CoinB>(account, tick_spacing, init_sqrt_price, uri);
    }

    public entry fun add_fee_tier(account: &signer, tick_spacing: u64, fee_rate: u64) {
        fee_tier::add_fee_tier(account, tick_spacing, fee_rate);
    }

    public entry fun delete_fee_tier(account: &signer, tick_spacing: u64) {
        fee_tier::delete_fee_tier(account, tick_spacing);
    }

    public entry fun update_fee_tier(account: &signer, tick_spacing: u64, fee_rate: u64) {
        fee_tier::update_fee_tier(account, tick_spacing, fee_rate);
    }

    public entry fun claim_ref_fee<CoinA>(receiver: &signer, name: String) {
        partner::claim_ref_fee<CoinA>(receiver, name);
    }

    public entry fun create_partner(
        account: &signer,
        name: String,
        fee_rate: u64,
        receiver_address: address,
        start_time: u64,
        end_time: u64
    ) {
        partner::create_partner(account, name, fee_rate, receiver_address, start_time, end_time);
    }

    public entry fun update_fee_rate<CoinA, CoinB>(account: &signer, pool_address: address, new_fee_rate: u64) {
        pool::update_fee_rate<CoinA, CoinB>(account, pool_address, new_fee_rate);
    }

    public entry fun accept_rewarder_authority<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8
    ) {
        pool::accept_rewarder_authority<CoinA, CoinB>(account, pool_address, rewarder_index);
    }

    public entry fun add_liquidity<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        delta_liquidity: u128,
        max_amount_a: u64,
        max_amount_b: u64,
        tick_lower: u64,
        tick_upper: u64,
        is_new_position: bool,
        position_index: u64
    ) {
        let position_id = if (is_new_position) {
            pool::open_position<CoinA, CoinB>(
                account,
                pool_address,
                i64::from_u64(tick_lower),
                i64::from_u64(tick_upper)
            )
        } else {
            pool::check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
            let (tick_lower_checked, tick_upper_checked) = pool::get_position_tick_range<CoinA, CoinB>(
                pool_address,
                position_index
            );
            assert!(i64::eq(i64::from_u64(tick_lower), tick_lower_checked), E_TICK_RANGE_MISMATCH);
            assert!(i64::eq(i64::from_u64(tick_upper), tick_upper_checked), E_TICK_RANGE_MISMATCH);
            position_index
        };
        let liquidity_state = pool::add_liquidity<CoinA, CoinB>(pool_address, delta_liquidity, position_id);
        let (required_amount_a, required_amount_b) = pool::add_liqudity_pay_amount<CoinA, CoinB>(&liquidity_state);
        assert!(required_amount_a <= max_amount_a, E_EXCEED_MAX_A);
        assert!(required_amount_b <= max_amount_b, E_EXCEED_MAX_B);
        let coin_a = if (required_amount_a > 0) {
            coin::withdraw<CoinA>(account, required_amount_a)
        } else {
            coin::zero<CoinA>()
        };
        let coin_b = if (required_amount_b > 0) {
            coin::withdraw<CoinB>(account, required_amount_b)
        } else {
            coin::zero<CoinB>()
        };
        pool::repay_add_liquidity<CoinA, CoinB>(coin_a, coin_b, liquidity_state);
    }

    public entry fun collect_fee<CoinA, CoinB>(owner: &signer, pool_address: address, pos_index: u64) {
        let owner_address = signer::address_of(owner);
        let (fee_a, fee_b) = pool::collect_fee<CoinA, CoinB>(owner, pool_address, pos_index, true);
        if (!coin::is_account_registered<CoinA>(owner_address)) {
            coin::register<CoinA>(owner);
        };
        if (!coin::is_account_registered<CoinB>(owner_address)) {
            coin::register<CoinB>(owner);
        };
        coin::deposit<CoinA>(owner_address, fee_a);
        coin::deposit<CoinB>(owner_address, fee_b);
    }

    public entry fun collect_protocol_fee<CoinA, CoinB>(protocol_owner: &signer, pool_address: address) {
        let protocol_owner_address = signer::address_of(protocol_owner);
        let (fee_a, fee_b) = pool::collect_protocol_fee<CoinA, CoinB>(protocol_owner, pool_address);
        if (!coin::is_account_registered<CoinA>(protocol_owner_address)) {
            coin::register<CoinA>(protocol_owner);
        };
        if (!coin::is_account_registered<CoinB>(protocol_owner_address)) {
            coin::register<CoinB>(protocol_owner);
        };
        coin::deposit<CoinA>(protocol_owner_address, fee_a);
        coin::deposit<CoinB>(protocol_owner_address, fee_b);
    }

    public entry fun collect_rewarder<CoinA, CoinB, CoinC>(
        owner: &signer,
        pool_address: address,
        rewarder_index: u8,
        pos_index: u64
    ) {
        let owner_address = signer::address_of(owner);
        if (!coin::is_account_registered<CoinC>(owner_address)) {
            coin::register<CoinC>(owner);
        };
        coin::deposit<CoinC>(
            owner_address,
            pool::collect_rewarder<CoinA, CoinB, CoinC>(owner, pool_address, pos_index, rewarder_index, true)
        );
    }

    public entry fun initialize_rewarder<CoinA, CoinB, CoinC>(
        account: &signer,
        pool_address: address,
        authority: address,
        rewarder_index: u64
    ) {
        pool::initialize_rewarder<CoinA, CoinB, CoinC>(account, pool_address, authority, rewarder_index);
    }

    public entry fun remove_liquidity<CoinA, CoinB>(
        owner: &signer,
        pool_address: address,
        delta_liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        pos_index: u64,
        is_close: bool
    ) {
        let (coin_a, coin_b) = pool::remove_liquidity<CoinA, CoinB>(owner, pool_address, delta_liquidity, pos_index);

        assert!(coin::value<CoinA>(&coin_a) >= min_amount_a, E_LESS_THAN_MIN);
        assert!(coin::value<CoinB>(&coin_b) >= min_amount_b, E_LESS_THAN_MIN);
        let owner_address = signer::address_of(owner);
        if (!coin::is_account_registered<CoinA>(owner_address)) {
            coin::register<CoinA>(owner);
        };
        if (!coin::is_account_registered<CoinB>(owner_address)) {
            coin::register<CoinB>(owner);
        };
        coin::deposit<CoinA>(owner_address, coin_a);
        coin::deposit<CoinB>(owner_address, coin_b);
        let (fee_a, fee_b) = pool::collect_fee<CoinA, CoinB>(owner, pool_address, pos_index, false);
        coin::deposit<CoinA>(owner_address, fee_a);
        coin::deposit<CoinB>(owner_address, fee_b);
        if (is_close) {
            pool::checked_close_position<CoinA, CoinB>(owner, pool_address, pos_index);
        };
    }

    public entry fun transfer_rewarder_authority<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8,
        new_authority: address
    ) {
        pool::transfer_rewarder_authority<CoinA, CoinB>(account, pool_address, rewarder_index, new_authority);
    }

    public entry fun update_pool_uri<CoinA, CoinB>(account: &signer, pool_address: address, new_uri: String) {
        pool::update_pool_uri<CoinA, CoinB>(account, pool_address, new_uri);
    }

    public entry fun accept_partner_receiver(receiver: &signer, name: String) {
        partner::accept_receiver(receiver, name);
    }

    public entry fun add_liquidity_fix_token<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        amount_a: u64,
        amount_b: u64,
        fix_a: bool,
        tick_lower: u64,
        tick_upper: u64,
        is_new_position: bool,
        position_index: u64
    ) {
        let position_id = if (is_new_position) {
            pool::open_position<CoinA, CoinB>(
                account,
                pool_address,
                i64::from_u64(tick_lower),
                i64::from_u64(tick_upper)
            )
        } else {
            pool::check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
            let (tick_lower_checked, tick_upper_checked) = pool::get_position_tick_range<CoinA, CoinB>(
                pool_address,
                position_index
            );
            assert!(i64::eq(i64::from_u64(tick_lower), tick_lower_checked), E_TICK_RANGE_MISMATCH);
            assert!(i64::eq(i64::from_u64(tick_upper), tick_upper_checked), E_TICK_RANGE_MISMATCH);
            position_index
        };
        let fixed_amount = if (fix_a) {
            amount_a
        } else {
            amount_b
        };
        let liquidity_state = pool::add_liquidity_fix_coin<CoinA, CoinB>(
            pool_address,
            fixed_amount,
            fix_a,
            position_id
        );
        let (required_amount_a, required_amount_b) = pool::add_liqudity_pay_amount<CoinA, CoinB>(&liquidity_state);
        if (fix_a) {
            assert!(amount_a == required_amount_a && required_amount_b <= amount_b, E_EXCEED_MAX_B);
        } else {
            assert!(amount_b == required_amount_b && required_amount_a <= amount_a, E_EXCEED_MAX_A);
        };
        let coin_a = if (required_amount_a > 0) {
            coin::withdraw<CoinA>(account, required_amount_a)
        } else {
            coin::zero<CoinA>()
        };
        let coin_b = if (required_amount_b > 0) {
            coin::withdraw<CoinB>(account, required_amount_b)
        } else {
            coin::zero<CoinB>()
        };
        pool::repay_add_liquidity<CoinA, CoinB>(coin_a, coin_b, liquidity_state);
    }

    public entry fun close_position<CoinA, CoinB>(account: &signer, pool_address: address, position_index: u64) {
        if (!pool::checked_close_position<CoinA, CoinB>(account, pool_address, position_index)) {
            abort E_CLOSE_POSITION_FAIL
        };
    }

    public entry fun pause_pool<CoinA, CoinB>(account: &signer, pool_address: address) {
        pool::pause<CoinA, CoinB>(account, pool_address);
    }

    public entry fun transfer_partner_receiver(account: &signer, name: String, new_receiver: address) {
        partner::transfer_receiver(account, name, new_receiver);
    }

    public entry fun unpause_pool<CoinA, CoinB>(account: &signer, pool_address: address) {
        pool::unpause<CoinA, CoinB>(account, pool_address);
    }

    public entry fun update_partner_fee_rate(receiver: &signer, name: String, new_fee_rate: u64) {
        partner::update_fee_rate(receiver, name, new_fee_rate);
    }

    public entry fun update_partner_time(receiver: &signer, name: String, start_time: u64, end_time: u64) {
        partner::update_time(receiver, name, start_time, end_time);
    }

    public entry fun update_rewarder_emission<CoinA, CoinB, CoinC>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8,
        emissions_per_second: u128
    ) {
        pool::update_emission<CoinA, CoinB, CoinC>(account, pool_address, rewarder_index, emissions_per_second);
    }

    // decompiled from Move bytecode v6
}

