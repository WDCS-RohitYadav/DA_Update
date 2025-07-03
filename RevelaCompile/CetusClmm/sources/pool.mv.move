module dexlyn_clmm::pool {

    use std::bit_vector::{Self, BitVector};
    use std::option;
    use std::string::{Self, String, utf8};
    use std::table::{Self, Table};
    use std::type_info::{Self, TypeInfo};
    use std::vector;
    use aptos_token_objects::token;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use aptos_framework::signer;
    use aptos_framework::timestamp;

    use dexlyn_clmm::clmm_math;
    use dexlyn_clmm::config;
    use dexlyn_clmm::fee_tier;
    use dexlyn_clmm::partner;
    use dexlyn_clmm::position_nft;
    use dexlyn_clmm::tick_math;
    use integer_mate::full_math_u128;
    use integer_mate::full_math_u64;
    use integer_mate::i128::{Self, I128};
    use integer_mate::i64::{Self, I64};
    use integer_mate::math_u128;
    use integer_mate::math_u64;

    friend dexlyn_clmm::factory;

    /// tick offset is negative
    const E_NEGATIVE_TICK_OFFSET: u64 = 1;

    /// coin value does not match expected amount
    const E_AMOUNT_MISMATCH: u64 = 2;

    /// overflow in liquidity
    const E_OVERFLOW: u64 = 3;

    /// overflow in liquidity subtraction
    const E_OVERFLOW_SUB: u64 = 4;

    /// tick index is not found
    const E_TICK_INDEX_NOT_FOUND: u64 = 5;

    /// tick is not found
    const E_TICK_NOT_FOUND: u64 = 6;

    /// liquidity is zero
    const E_ZERO_LIQUIDITY: u64 = 7;

    /// swap tick is out of range
    const E_SWAP_OUT_OF_RANGE: u64 = 8;

    /// overflow in subtraction
    const E_OVERFLOW_SUB_REMAINER: u64 = 9;

    /// overflow in swap result amount_in
    const E_OVERFLOW_AMOUNT_IN: u64 = 10;

    /// overflow in swap result amount_out
    const E_OVERFLOW_AMOUNT_OUT: u64 = 11;

    /// overflow in swap result fee_amount
    const E_OVERFLOW_FEE_AMOUNT: u64 = 12;

    /// fee rate exceeds max
    const E_FEE_RATE_TOO_HIGH: u64 = 13;

    /// pool does not exist
    const E_POOL_NOT_EXISTS: u64 = 14;

    /// price limit assertion fails
    const E_PRICE_LIMIT_INVALID: u64 = 15;

    /// rewarder index is invalid
    const E_INVALID_REWARDER_INDEX: u64 = 16;

    /// reward token balance is insufficient
    const E_INSUFFICIENT_REWARD_BALANCE: u64 = 17;

    /// rewarder type mismatches
    const E_REWARDER_TYPE_MISMATCH: u64 = 18;

    /// not authority for rewarder
    const E_NOT_AUTHORITY: u64 = 19;

    /// timestamp is invalid
    const E_INVALID_TIMESTAMP: u64 = 20;

    /// position NFT is not owned by signer
    const E_POSITION_NFT_NOT_OWNED: u64 = 21;

    /// position is not found in various position-related functions
    const E_POSITION_NOT_FOUND: u64 = 22;

    /// tick index or tick range is invalid in open_position
    const E_INVALID_TICK_INDEX: u64 = 23;

    /// pool is paused
    const E_POOL_PAUSED: u64 = 24;

    /// pool is not empty
    const E_POOL_NOT_EMPTY: u64 = 25;

    /// overflow in reward amount calculation
    const E_OVERFLOW_REWARD_AMOUNT: u64 = 26;

    /// overflow in fee owed calculation
    const E_OVERFLOW_FEE_OWED: u64 = 27;

    /// overflow in position liquidity update
    const E_OVERFLOW_POSITION_LIQUIDITY: u64 = 28;

    /// when CoinA and CoinB are the same type in new
    const E_SAME_COIN_TYPE: u64 = 29;

    /// sqrt price is invalid
    const E_INVALID_SQRT_PRICE: u64 = 30;

    /// reset_init_price is called
    const E_RESET_INIT_PRICE_DISABLED: u64 = 31;

    /// not allowed to set NFT URI
    const E_NOT_ALLOWED_SET_NFT_URI: u64 = 32;

    /// URI is empty in update_pool_uri
    const E_EMPTY_URI: u64 = 33;


    const TICK_INDEX_GROUP_SIZE: u64 = 1000;
    const PROTOCOL_FEE_DENOMINATOR: u64 = 10000;
    const MAX_REWARDERS: u64 = 3;

    #[event]
    struct AcceptRewardAuthEvent has drop, store {
        pool_address: address,
        rewarder_index: u8,
        authority: address,
        timestamp: u64,
    }

    #[event]
    struct AddLiquidityEvent has drop, store {
        pool_address: address,
        tick_lower: I64,
        tick_upper: I64,
        liquidity: u128,
        amount_a: u64,
        amount_b: u64,
        position_index: u64,
        timestamp: u64,
        vault_a_amount: u64,
        vault_b_amount: u64,
    }

    struct AddLiquidityReceipt<phantom CoinA, phantom CoinB> {
        pool_address: address,
        amount_a: u64,
        amount_b: u64,
    }

    struct CalculatedSwapResult has copy, drop, store {
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        fee_rate: u64,
        after_sqrt_price: u128,
        is_exceed: bool,
        step_results: vector<SwapStepResult>,
    }

    #[event]
    struct ClosePositionEvent has drop, store {
        user: address,
        pool: address,
        position_index: u64,
        timestamp: u64,
    }

    #[event]
    struct CollectFeeEvent has drop, store {
        position_index: u64,
        user: address,
        pool_address: address,
        amount_a: u64,
        amount_b: u64,
        timestamp: u64,
    }

    #[event]
    struct CollectProtocolFeeEvent has drop, store {
        pool_address: address,
        amount_a: u64,
        amount_b: u64,
        timestamp: u64,
    }

    #[event]
    struct CollectRewardEvent has drop, store {
        position_index: u64,
        user: address,
        pool_address: address,
        amount: u64,
        rewarder_index: u8,
        timestamp: u64,
    }

    struct FlashSwapReceipt<phantom CoinA, phantom CoinB> {
        pool_address: address,
        a2b: bool,
        partner_name: String,
        pay_amount: u64,
        ref_fee_amount: u64,
    }

    #[event]
    struct OpenPositionEvent has drop, store {
        user: address,
        pool: address,
        tick_lower: I64,
        tick_upper: I64,
        position_index: u64,
        timestamp: u64,
    }

    struct Pool<phantom CoinA, phantom CoinB> has key {
        index: u64,
        collection_name: String,
        coin_a: Coin<CoinA>,
        coin_b: Coin<CoinB>,
        tick_spacing: u64,
        fee_rate: u64,
        liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: I64,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        fee_protocol_coin_a: u64,
        fee_protocol_coin_b: u64,
        tick_indexes: Table<u64, BitVector>,
        ticks: Table<I64, Tick>,
        rewarder_infos: vector<Rewarder>,
        rewarder_last_updated_time: u64,
        positions: Table<u64, Position>,
        position_index: u64,
        is_pause: bool,
        uri: String,
        signer_cap: SignerCapability,
    }

    struct Position has copy, drop, store {
        pool: address,
        index: u64,
        liquidity: u128,
        tick_lower_index: I64,
        tick_upper_index: I64,
        fee_growth_inside_a: u128,
        fee_owed_a: u64,
        fee_growth_inside_b: u128,
        fee_owed_b: u64,
        rewarder_infos: vector<PositionRewarder>,
    }

    struct PositionRewarder has copy, drop, store {
        growth_inside: u128,
        amount_owed: u64,
    }

    #[event]
    struct RemoveLiquidityEvent has drop, store {
        pool_address: address,
        tick_lower: I64,
        tick_upper: I64,
        liquidity: u128,
        amount_a: u64,
        amount_b: u64,
        position_index: u64,
        timestamp: u64,
        vault_a_amount: u64,
        vault_b_amount: u64,
    }

    struct Rewarder has copy, drop, store {
        coin_type: TypeInfo,
        authority: address,
        pending_authority: address,
        emissions_per_second: u128,
        growth_global: u128,
    }

    #[event]
    struct AssetSwapEvent has drop, store {
        atob: bool,
        pool_address: address,
        swap_from: address,
        partner: String,
        amount_in: u64,
        amount_out: u64,
        ref_amount: u64,
        fee_amount: u64,
        vault_a_amount: u64,
        vault_b_amount: u64,
        timestamp: u64,
        current_sqrt_price: u128
    }

    struct SwapResult has copy, drop {
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        ref_fee_amount: u64,
    }

    struct SwapStepResult has copy, drop, store {
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        current_liquidity: u128,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        remainer_amount: u64,
    }

    struct Tick has copy, drop, store {
        index: I64,
        sqrt_price: u128,
        liquidity_net: I128,
        liquidity_gross: u128,
        fee_growth_outside_a: u128,
        fee_growth_outside_b: u128,
        rewarders_growth_outside: vector<u128>,
    }

    #[event]
    struct TransferRewardAuthEvent has drop, store {
        pool_address: address,
        rewarder_index: u8,
        old_authority: address,
        new_authority: address,
        timestamp: u64,
    }

    #[event]
    struct UpdateEmissionEvent has drop, store {
        pool_address: address,
        rewarder_index: u8,
        emissions_per_second: u128,
        timestamp: u64,
    }

    #[event]
    struct UpdateFeeRateEvent has drop, store {
        pool_address: address,
        old_fee_rate: u64,
        new_fee_rate: u64,
        timestamp: u64,
    }

    public(friend) fun new<CoinA, CoinB>(
        account: &signer,
        tick_spacing: u64,
        current_sqrt_price: u128,
        pool_index: u64,
        uri: String,
        signer_cap: SignerCapability
    ): String {
        assert!(type_info::type_of<CoinA>() != type_info::type_of<CoinB>(), E_SAME_COIN_TYPE);
        let collection_name = position_nft::create_collection<CoinA, CoinB>(
            account,
            tick_spacing,
            string::utf8(b"Cetus Liquidity Position"),
            uri
        );
        let pool = Pool<CoinA, CoinB> {
            index: pool_index,
            collection_name: collection_name,
            coin_a: coin::zero<CoinA>(),
            coin_b: coin::zero<CoinB>(),
            tick_spacing: tick_spacing,
            fee_rate: fee_tier::get_fee_rate(tick_spacing),
            liquidity: 0,
            current_sqrt_price: current_sqrt_price,
            current_tick_index: tick_math::get_tick_at_sqrt_price(current_sqrt_price),
            fee_growth_global_a: 0,
            fee_growth_global_b: 0,
            fee_protocol_coin_a: 0,
            fee_protocol_coin_b: 0,
            tick_indexes: table::new<u64, BitVector>(),
            ticks: table::new<I64, Tick>(),
            rewarder_infos: vector::empty<Rewarder>(),
            rewarder_last_updated_time: 0,
            positions: table::new<u64, Position>(),
            position_index: 1,
            is_pause: false,
            uri: uri,
            signer_cap: signer_cap,
        };
        move_to<Pool<CoinA, CoinB>>(account, pool);
        // token::initialize_token_store(account);
        position_nft::mint(account, account, pool_index, 0, uri, collection_name);
        collection_name
    }

    public fun accept_rewarder_authority<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8
    ) acquires Pool {
        let account_addr = signer::address_of(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        assert!((rewarder_index as u64) < vector::length<Rewarder>(&pool.rewarder_infos), E_INVALID_REWARDER_INDEX);
        let rewarder = vector::borrow_mut<Rewarder>(&mut pool.rewarder_infos, (rewarder_index as u64));
        assert!(rewarder.pending_authority == account_addr, E_NOT_AUTHORITY);
        rewarder.pending_authority = @0x0;
        rewarder.authority = account_addr;
        let accept_reward_event = AcceptRewardAuthEvent {
            pool_address: pool_address,
            rewarder_index: rewarder_index,
            authority: account_addr,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<AcceptRewardAuthEvent>(accept_reward_event);
    }

    public fun add_liqudity_pay_amount<CoinA, CoinB>(receipt: &AddLiquidityReceipt<CoinA, CoinB>): (u64, u64) {
        (receipt.amount_a, receipt.amount_b)
    }

    public fun add_liquidity<CoinA, CoinB>(
        pool_address: address,
        liquidity: u128,
        position_index: u64
    ): AddLiquidityReceipt<CoinA, CoinB> acquires Pool {
        assert!(liquidity != 0, E_ZERO_LIQUIDITY);
        add_liquidity_internal<CoinA, CoinB>(pool_address, position_index, false, liquidity, 0, false)
    }

    public fun add_liquidity_fix_coin<CoinA, CoinB>(
        pool_address: address,
        amount: u64,
        fix_a: bool,
        position_index: u64
    ): AddLiquidityReceipt<CoinA, CoinB> acquires Pool {
        assert!(amount > 0, E_AMOUNT_MISMATCH);
        add_liquidity_internal<CoinA, CoinB>(pool_address, position_index, true, 0, amount, fix_a)
    }

    fun add_liquidity_internal<CoinA, CoinB>(
        pool_address: address,
        position_index: u64,
        is_fixed_token: bool,
        liquidity: u128,
        amount: u64,
        fix_a: bool
    ): AddLiquidityReceipt<CoinA, CoinB> acquires Pool {
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        update_rewarder<CoinA, CoinB>(pool);
        let (tick_lower, tick_upper) = get_position_tick_range_by_pool<CoinA, CoinB>(pool, position_index);
        let (fee_growth_inside_a, fee_growth_inside_b) = get_fee_in_tick_range<CoinA, CoinB>(
            pool,
            tick_lower,
            tick_upper
        );
        let reward_in_tick_range = get_reward_in_tick_range<CoinA, CoinB>(pool, tick_lower, tick_upper);
        let position = table::borrow_mut<u64, Position>(&mut pool.positions, position_index);
        update_position_fee_and_reward(position, fee_growth_inside_a, fee_growth_inside_b, reward_in_tick_range);
        let (amount_a, amount_b, position_liquidity) = if (is_fixed_token) {
            let (liquidity_from_amount, amount_a, amount_b) = clmm_math::get_liquidity_from_amount(
                tick_lower,
                tick_upper,
                pool.current_tick_index,
                pool.current_sqrt_price,
                amount,
                fix_a
            );
            (amount_a, amount_b, liquidity_from_amount)
        } else {
            let (amount_a, amount_b) = clmm_math::get_amount_by_liquidity(
                tick_lower,
                tick_upper,
                pool.current_tick_index,
                pool.current_sqrt_price,
                liquidity,
                true
            );
            (amount_a, amount_b, liquidity)
        };
        update_position_liquidity(position, position_liquidity, true);
        upsert_tick_by_liquidity<CoinA, CoinB>(pool, tick_lower, position_liquidity, true, false);
        upsert_tick_by_liquidity<CoinA, CoinB>(pool, tick_upper, position_liquidity, true, true);
        let (updated_liquidity, overflow) = if (i64::gte(pool.current_tick_index, tick_lower) && i64::lt(
            pool.current_tick_index,
            tick_upper
        )) {
            math_u128::overflowing_add(pool.liquidity, position_liquidity)
        } else {
            (pool.liquidity, false)
        };
        assert!(!overflow, E_OVERFLOW);
        pool.liquidity = updated_liquidity;
        let add_liquidity_event = AddLiquidityEvent {
            pool_address: pool_address,
            tick_lower: tick_lower,
            tick_upper: tick_upper,
            liquidity: position_liquidity,
            amount_a: amount_a,
            amount_b: amount_b,
            position_index: position_index,
            vault_a_amount: coin::value<CoinA>(&pool.coin_a),
            vault_b_amount: coin::value<CoinB>(&pool.coin_b),
            timestamp: timestamp::now_seconds(),
        };
        event::emit<AddLiquidityEvent>(add_liquidity_event);
        AddLiquidityReceipt<CoinA, CoinB> {
            pool_address: pool_address,
            amount_a: amount_a,
            amount_b: amount_b,
        }
    }

    fun assert_status<CoinA, CoinB>(pool: &Pool<CoinA, CoinB>) {
        config::assert_protocol_status();
        if (pool.is_pause) {
            abort E_POOL_PAUSED
        };
    }

    fun borrow_mut_tick_with_default(
        tick_indexes: &mut table::Table<u64, BitVector>,
        ticks: &mut table::Table<I64, Tick>,
        tick_spacing: u64,
        tick_index: I64
    ): &mut Tick {
        let (tick_indexes_key, bit_index) = tick_position(tick_index, tick_spacing);
        if (!table::contains<u64, BitVector>(tick_indexes, tick_indexes_key)) {
            table::add<u64, BitVector>(tick_indexes, tick_indexes_key, bit_vector::new(TICK_INDEX_GROUP_SIZE));
        };
        bit_vector::set(table::borrow_mut<u64, BitVector>(tick_indexes, tick_indexes_key), bit_index);
        if (!table::contains<I64, Tick>(ticks, tick_index)) {
            table::borrow_mut_with_default<I64, Tick>(ticks, tick_index, default_tick(tick_index))
        } else {
            table::borrow_mut<I64, Tick>(ticks, tick_index)
        }
    }

    fun borrow_tick<CoinA, CoinB>(pool: &Pool<CoinA, CoinB>, tick_index: I64): option::Option<Tick> {
        let (tick_indexes_key, _) = tick_position(tick_index, pool.tick_spacing);
        if (!table::contains<u64, BitVector>(&pool.tick_indexes, tick_indexes_key)) {
            return option::none<Tick>()
        };
        if (!table::contains<I64, Tick>(&pool.ticks, tick_index)) {
            return option::none<Tick>()
        };
        option::some<Tick>(*table::borrow<I64, Tick>(&pool.ticks, tick_index))
    }

    #[view]
    public fun calculate_swap_result<CoinA, CoinB>(
        pool_address: address,
        a2b: bool,
        by_amount_in: bool,
        amount: u64
    ): CalculatedSwapResult acquires Pool {
        let pool = borrow_global<Pool<CoinA, CoinB>>(pool_address);
        let current_sqrt_price = pool.current_sqrt_price;
        let current_liquidity = pool.liquidity;
        let default_swap = default_swap_result();
        let remainer_amount = amount;
        let current_tick_index = pool.current_tick_index;
        let max_tick = tick_max(pool.tick_spacing);
        let calculated_swap = CalculatedSwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            fee_rate: pool.fee_rate,
            after_sqrt_price: pool.current_sqrt_price,
            is_exceed: false,
            step_results: vector::empty<SwapStepResult>(),
        };
        while (remainer_amount > 0) {
            if (i64::gt(current_tick_index, max_tick) || i64::lt(current_tick_index, tick_min(pool.tick_spacing))) {
                calculated_swap.is_exceed = true;
                break
            };
            let next_tick = get_next_tick_for_swap<CoinA, CoinB>(pool, current_tick_index, a2b, max_tick);
            if (option::is_none<Tick>(&next_tick)) {
                calculated_swap.is_exceed = true;
                break
            };
            let new_tick = option::destroy_some<Tick>(next_tick);
            let target_sqrt_price = new_tick.sqrt_price;
            let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
                current_sqrt_price,
                target_sqrt_price,
                current_liquidity,
                remainer_amount,
                pool.fee_rate,
                a2b,
                by_amount_in
            );
            if (amount_in != 0 || fee_amount != 0) {
                if (by_amount_in) {
                    let sub_remainer_amount = check_sub_remainer_amount(remainer_amount, amount_in);
                    remainer_amount = check_sub_remainer_amount(sub_remainer_amount, fee_amount);
                } else {
                    remainer_amount = check_sub_remainer_amount(remainer_amount, amount_out);
                };
                update_swap_result(&mut default_swap, amount_in, amount_out, fee_amount);
            };
            let swap_step = SwapStepResult {
                current_sqrt_price: current_sqrt_price,
                target_sqrt_price: target_sqrt_price,
                current_liquidity: current_liquidity,
                amount_in: amount_in,
                amount_out: amount_out,
                fee_amount: fee_amount,
                remainer_amount: remainer_amount,
            };
            vector::push_back<SwapStepResult>(&mut calculated_swap.step_results, swap_step);
            if (next_sqrt_price == new_tick.sqrt_price) {
                current_sqrt_price = new_tick.sqrt_price;
                let liquidity_delta = if (a2b) {
                    i128::neg(new_tick.liquidity_net)
                } else {
                    new_tick.liquidity_net
                };
                if (!i128::is_neg(liquidity_delta)) {
                    let (new_liquidity, overflow) = math_u128::overflowing_add(
                        current_liquidity,
                        i128::abs_u128(liquidity_delta)
                    );
                    if (overflow) {
                        abort E_OVERFLOW
                    };
                    current_liquidity = new_liquidity;
                } else {
                    let (new_liquidity, overflow) = math_u128::overflowing_sub(
                        current_liquidity,
                        i128::abs_u128(liquidity_delta)
                    );
                    if (overflow) {
                        abort E_OVERFLOW_SUB
                    };
                    current_liquidity = new_liquidity;
                };
            } else {
                current_sqrt_price = next_sqrt_price;
            };
            if (a2b) {
                current_tick_index = i64::sub(new_tick.index, i64::from(1));
                continue
            };
            current_tick_index = new_tick.index;
        };
        calculated_swap.amount_in = default_swap.amount_in;
        calculated_swap.amount_out = default_swap.amount_out;
        calculated_swap.fee_amount = default_swap.fee_amount;
        calculated_swap.after_sqrt_price = current_sqrt_price;
        calculated_swap
    }

    public fun check_position_authority<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        position_index: u64
    ) acquires Pool {
        let pool = borrow_global<Pool<CoinA, CoinB>>(pool_address);
        if (!table::contains<u64, Position>(&pool.positions, position_index)) {
            abort E_POSITION_NOT_FOUND
        };
        assert!(
        position_nft::is_position_nft_owner(
            signer::address_of(account),
            pool.collection_name,
            pool.index,
            position_index
        ),
        E_POSITION_NFT_NOT_OWNED
    );
    }

    fun check_sub_remainer_amount(remaining_amount: u64, subtract_amount: u64): u64 {
        let (result, overflow) = math_u64::overflowing_sub(remaining_amount, subtract_amount);
        if (overflow) {
            abort E_OVERFLOW_SUB_REMAINER
        };
        result
    }

    public fun checked_close_position<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        position_index: u64
    ): bool acquires Pool {
        check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        let position = table::borrow<u64, Position>(&pool.positions, position_index);
        if (position.liquidity != 0) {
            return false
        };
        if (position.fee_owed_a > 0 || position.fee_owed_b > 0) {
            return false
        };
        let rewarder_index = 0;
        while (rewarder_index < MAX_REWARDERS) {
            if (vector::borrow<PositionRewarder>(&position.rewarder_infos, rewarder_index).amount_owed != 0) {
                return false
            };
            rewarder_index = rewarder_index + 1;
        };
        table::remove<u64, Position>(&mut pool.positions, position_index);
        let signer_cap = account::create_signer_with_capability(&pool.signer_cap);
        let user_address = signer::address_of(account);
        position_nft::burn_by_collection_and_index(
                &signer_cap,
                user_address,
                pool.collection_name,
                pool.index,
                position_index
        );

        let close_position_event = ClosePositionEvent {
            user: user_address,
            pool: pool_address,
            position_index: position_index,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<ClosePositionEvent>(close_position_event);
        true
    }

    public fun collect_fee<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        position_index: u64,
        update: bool
    ): (coin::Coin<CoinA>, coin::Coin<CoinB>) acquires Pool {
        check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        let position = if (update) {
            let (tick_lower, tick_upper) = get_position_tick_range_by_pool<CoinA, CoinB>(pool, position_index);
            let (fee_growth_inside_a, fee_growth_inside_b) = get_fee_in_tick_range<CoinA, CoinB>(
                pool,
                tick_lower,
                tick_upper
            );
            let pos = table::borrow_mut<u64, Position>(&mut pool.positions, position_index);
            update_position_fee(pos, fee_growth_inside_a, fee_growth_inside_b);
            pos
        } else {
            table::borrow_mut<u64, Position>(&mut pool.positions, position_index)
        };
        let fee_a = position.fee_owed_a;
        let fee_b = position.fee_owed_b;
        position.fee_owed_a = 0;
        position.fee_owed_b = 0;
        let collect_fee_event = CollectFeeEvent {
            position_index: position_index,
            user: signer::address_of(account),
            pool_address: pool_address,
            amount_a: fee_a,
            amount_b: fee_b,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<CollectFeeEvent>(collect_fee_event);
        (coin::extract<CoinA>(&mut pool.coin_a, fee_a), coin::extract<CoinB>(&mut pool.coin_b, fee_b))
    }

    public fun collect_protocol_fee<CoinA, CoinB>(
        account: &signer,
        pool_address: address
    ): (coin::Coin<CoinA>, coin::Coin<CoinB>) acquires Pool {
        config::assert_protocol_fee_claim_authority(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        let amount_a = pool.fee_protocol_coin_a;
        let amount_b = pool.fee_protocol_coin_b;
        pool.fee_protocol_coin_a = 0;
        pool.fee_protocol_coin_b = 0;
        let collect_protocol_fee_event = CollectProtocolFeeEvent {
            pool_address: pool_address,
            amount_a: amount_a,
            amount_b: amount_b,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<CollectProtocolFeeEvent>(collect_protocol_fee_event);
        (coin::extract<CoinA>(&mut pool.coin_a, amount_a), coin::extract<CoinB>(&mut pool.coin_b, amount_b))
    }

    public fun collect_rewarder<CoinA, CoinB, T2>(
        account: &signer,
        pool_address: address,
        position_index: u64,
        rewarder_index: u8,
        update: bool
    ): coin::Coin<T2> acquires Pool {
        check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        update_rewarder<CoinA, CoinB>(pool);
        let position = if (update) {
            let (tick_lower, tick_upper) = get_position_tick_range_by_pool<CoinA, CoinB>(pool, position_index);
            let reward_in_tick_range = get_reward_in_tick_range<CoinA, CoinB>(pool, tick_lower, tick_upper);
            let position = table::borrow_mut<u64, Position>(&mut pool.positions, position_index);
            update_position_rewarder(position, reward_in_tick_range);
            position
        } else {
            table::borrow_mut<u64, Position>(&mut pool.positions, position_index)
        };
        let signer_cap = account::create_signer_with_capability(&pool.signer_cap);
        let position_rewarder = &mut vector::borrow_mut<PositionRewarder>(
            &mut position.rewarder_infos,
            (rewarder_index as u64)
        ).amount_owed;
        let reward_coin = coin::withdraw<T2>(&signer_cap, *position_rewarder);
        *position_rewarder = 0;
        let collect_reward_event = CollectRewardEvent {
            position_index: position_index,
            user: signer::address_of(account),
            pool_address: pool_address,
            amount: coin::value<T2>(&reward_coin),
            rewarder_index: rewarder_index,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<CollectRewardEvent>(collect_reward_event);
        reward_coin
    }

    fun cross_tick_and_update_liquidity<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, tick_index: I64, a2b: bool) {
        let tick = table::borrow_mut<I64, Tick>(&mut pool.ticks, tick_index);
        let liquidity_delta = if (a2b) {
            i128::neg(tick.liquidity_net)
        } else {
            tick.liquidity_net
        };
        if (!i128::is_neg(liquidity_delta)) {
            let (new_liquidity, overflow) = math_u128::overflowing_add(pool.liquidity, i128::abs_u128(liquidity_delta));
            if (overflow) {
                abort E_OVERFLOW
            };
            pool.liquidity = new_liquidity;
        } else {
            let (new_liquidity, overflow) = math_u128::overflowing_sub(pool.liquidity, i128::abs_u128(liquidity_delta));
            if (overflow) {
                abort E_OVERFLOW_SUB
            };
            pool.liquidity = new_liquidity;
        };
        tick.fee_growth_outside_a = math_u128::wrapping_sub(pool.fee_growth_global_a, tick.fee_growth_outside_a);
        tick.fee_growth_outside_b = math_u128::wrapping_sub(pool.fee_growth_global_b, tick.fee_growth_outside_b);
        let i = 0;
        while (i < vector::length<Rewarder>(&pool.rewarder_infos)) {
            *vector::borrow_mut<u128>(&mut tick.rewarders_growth_outside, i) = math_u128::wrapping_sub(
                vector::borrow<Rewarder>(&pool.rewarder_infos, i).growth_global,
                *vector::borrow<u128>(&tick.rewarders_growth_outside, i)
            );
            i = i + 1;
        };
    }

    fun default_swap_result(): SwapResult {
        SwapResult {
            amount_in: 0,
            amount_out: 0,
            fee_amount: 0,
            ref_fee_amount: 0,
        }
    }

    fun default_tick(tick_index: I64): Tick {
        Tick {
            index: tick_index,
            sqrt_price: tick_math::get_sqrt_price_at_tick(tick_index),
            liquidity_net: i128::from(0),
            liquidity_gross: 0,
            fee_growth_outside_a: 0,
            fee_growth_outside_b: 0,
            rewarders_growth_outside: vector[0, 0, 0],
        }
    }

    public fun fetch_positions<CoinA, CoinB>(
        pool_address: address,
        position_index: u64,
        limit: u64
    ): (u64, vector<Position>) acquires Pool {
        let pool = borrow_global<Pool<CoinA, CoinB>>(pool_address);
        let position = vector::empty<Position>();
        let count = 0;
        while (count < limit && position_index < pool.position_index) {
            if (table::contains<u64, Position>(&pool.positions, position_index)) {
                vector::push_back<Position>(
                    &mut position,
                    *table::borrow<u64, Position>(&pool.positions, position_index)
                );
                count = count + 1;
            };
            position_index = position_index + 1;
        };
        (position_index, position)
    }

    public fun fetch_ticks<CoinA, CoinB>(
        pool_address: address,
        start_tick_index: u64,
        start_bit_index: u64,
        limit: u64
    ): (u64, u64, vector<Tick>) acquires Pool {
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        let tick_spacing = pool.tick_spacing;
        let tick_index_key = start_tick_index;
        let ticks_vec = vector::empty<Tick>();
        let bit_index = start_bit_index;
        let count = 0;
        while (tick_index_key >= 0 && tick_index_key <= tick_indexes_max(tick_spacing)) {
            if (table::contains<u64, BitVector>(&pool.tick_indexes, tick_index_key)) {
                let bitvec = table::borrow<u64, BitVector>(&pool.tick_indexes, tick_index_key);
                while (bit_index >= 0 && bit_index < TICK_INDEX_GROUP_SIZE) {
                    if (bit_vector::is_index_set(bitvec, bit_index)) {
                        let new_count = count + 1;
                        count = new_count;
                        vector::push_back<Tick>(
                            &mut ticks_vec,
                            *table::borrow<i64::I64, Tick>(
                                &pool.ticks,
                                i64::sub(
                                    i64::from((TICK_INDEX_GROUP_SIZE * tick_index_key + bit_index) * tick_spacing),
                                    tick_max(tick_spacing)
                                )
                            )
                        );
                        if (new_count == limit) {
                            return (tick_index_key, bit_index, ticks_vec)
                        };
                    };
                    bit_index = bit_index + 1;
                };
                bit_index = 0;
            };
            tick_index_key = tick_index_key + 1;
        };
        (tick_index_key, bit_index, ticks_vec)
    }

    public fun flash_swap<CoinA, CoinB>(
        pool_address: address,
        swap_from: address,
        partner_name: String,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        price_limit: u128
    ): (coin::Coin<CoinA>, coin::Coin<CoinB>, FlashSwapReceipt<CoinA, CoinB>) acquires Pool {
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        update_rewarder<CoinA, CoinB>(pool);
        if (a2b) {
            assert!(
                pool.current_sqrt_price > price_limit && price_limit >= tick_math::min_sqrt_price(),
                E_PRICE_LIMIT_INVALID
            );
        } else {
            assert!(
                pool.current_sqrt_price < price_limit && price_limit <= tick_math::max_sqrt_price(),
                E_PRICE_LIMIT_INVALID
            );
        };
        let swap_in_pool = swap_in_pool<CoinA, CoinB>(
            pool,
            a2b,
            by_amount_in,
            price_limit,
            amount,
            config::get_protocol_fee_rate(),
            partner::get_ref_fee_rate(partner_name)
        );
        let swap_event = AssetSwapEvent {
            atob: a2b,
            pool_address: pool_address,
            swap_from: swap_from,
            partner: partner_name,
            amount_in: swap_in_pool.amount_in,
            amount_out: swap_in_pool.amount_out,
            ref_amount: swap_in_pool.ref_fee_amount,
            fee_amount: swap_in_pool.fee_amount,
            vault_a_amount: coin::value<CoinA>(&pool.coin_a),
            vault_b_amount: coin::value<CoinB>(&pool.coin_b),
            timestamp: timestamp::now_seconds(),
            current_sqrt_price: pool.current_sqrt_price,
        };
        event::emit<AssetSwapEvent>(swap_event);
        let (output_coin_a, output_coin_b) = if (a2b) {
            (coin::zero<CoinA>(), coin::extract<CoinB>(&mut pool.coin_b, swap_in_pool.amount_out))
        } else {
            (coin::extract<CoinA>(&mut pool.coin_a, swap_in_pool.amount_out), coin::zero<CoinB>())
        };
        let receipt = FlashSwapReceipt<CoinA, CoinB> {
            pool_address: pool_address,
            a2b: a2b,
            partner_name: partner_name,
            pay_amount: swap_in_pool.amount_in + swap_in_pool.fee_amount,
            ref_fee_amount: swap_in_pool.ref_fee_amount,
        };
        (output_coin_a, output_coin_b, receipt)
    }

    fun get_fee_in_tick_range<CoinA, CoinB>(pool: &Pool<CoinA, CoinB>, tick_lower: I64, tick_upper: I64): (u128, u128) {
        let lower_tick_option = borrow_tick<CoinA, CoinB>(pool, tick_lower);
        let upper_tick_option = borrow_tick<CoinA, CoinB>(pool, tick_upper);
        let current_tick_index = pool.current_tick_index;
        let (fee_growth_inside_a, fee_growth_inside_b) = if (option::is_none<Tick>(&lower_tick_option)) {
            (pool.fee_growth_global_a, pool.fee_growth_global_b)
        } else {
            let lower_tick = option::borrow<Tick>(&lower_tick_option);
            if (i64::lt(current_tick_index, tick_lower)) {
                (math_u128::wrapping_sub(
                    pool.fee_growth_global_a,
                    lower_tick.fee_growth_outside_a
                ), math_u128::wrapping_sub(pool.fee_growth_global_b, lower_tick.fee_growth_outside_b))
            } else {
                (lower_tick.fee_growth_outside_a, lower_tick.fee_growth_outside_b)
            }
        };
        let (fee_growth_outside_a, fee_growth_outside_b) = if (option::is_none<Tick>(&upper_tick_option)) {
            (0, 0)
        } else {
            let upper_tick = option::borrow<Tick>(&upper_tick_option);
            if (i64::lt(current_tick_index, tick_upper)) {
                (upper_tick.fee_growth_outside_a, upper_tick.fee_growth_outside_b)
            } else {
                (math_u128::wrapping_sub(
                    pool.fee_growth_global_a,
                    upper_tick.fee_growth_outside_a
                ), math_u128::wrapping_sub(pool.fee_growth_global_b, upper_tick.fee_growth_outside_b))
            }
        };
        (math_u128::wrapping_sub(
            math_u128::wrapping_sub(pool.fee_growth_global_a, fee_growth_inside_a),
            fee_growth_outside_a
        ), math_u128::wrapping_sub(
            math_u128::wrapping_sub(pool.fee_growth_global_b, fee_growth_inside_b),
            fee_growth_outside_b
        ))
    }

    fun get_next_tick_for_swap<CoinA, CoinB>(
        pool: &Pool<CoinA, CoinB>,
        current_tick: I64,
        a2b: bool,
        max_tick: I64
    ): option::Option<Tick> {
        let tick_spacing = pool.tick_spacing;
        let (tick_index_key, bit_index) = tick_position(current_tick, tick_spacing);
        let search_bit_index = bit_index;
        let search_tick_index_key = tick_index_key;
        if (!a2b) {
            search_bit_index = bit_index + 1;
        };
        while (search_tick_index_key >= 0 && search_tick_index_key <= tick_indexes_max(tick_spacing)) {
            if (table::contains<u64, BitVector>(&pool.tick_indexes, search_tick_index_key)) {
                let bitvec = table::borrow<u64, BitVector>(&pool.tick_indexes, search_tick_index_key);
                while (search_bit_index >= 0 && search_bit_index < TICK_INDEX_GROUP_SIZE) {
                    if (bit_vector::is_index_set(bitvec, search_bit_index)) {
                        return option::some<Tick>(
                            *table::borrow<i64::I64, Tick>(
                                &pool.ticks,
                                i64::sub(
                                    i64::from(
                                        (TICK_INDEX_GROUP_SIZE * search_tick_index_key + search_bit_index) * tick_spacing
                                    ),
                                    max_tick
                                )
                            )
                        )
                    };
                    if (a2b) {
                        if (search_bit_index == 0) {
                            break
                        };
                        search_bit_index = search_bit_index - 1;
                        continue
                    };
                    search_bit_index = search_bit_index + 1;
                };
            };
            if (a2b) {
                if (search_tick_index_key == 0) {
                    return option::none<Tick>()
                };
                search_bit_index = TICK_INDEX_GROUP_SIZE - 1;
                search_tick_index_key = search_tick_index_key - 1;
                continue
            };
            search_bit_index = 0;
            search_tick_index_key = search_tick_index_key + 1;
        };
        option::none<Tick>()
    }

    #[view]
    public fun get_pool_index<CoinA, CoinB>(pool_address: address): u64 acquires Pool {
        borrow_global<Pool<CoinA, CoinB>>(pool_address).index
    }

    #[view]
    public fun get_pool_liquidity<CoinA, CoinB>(pool_address: address): u128 acquires Pool {
        if (!exists<Pool<CoinA, CoinB>>(pool_address)) {
            abort E_POOL_NOT_EXISTS
        };
        borrow_global<Pool<CoinA, CoinB>>(pool_address).liquidity
    }

    #[view]
    public fun get_position<CoinA, CoinB>(pool_address: address, position_index: u64): Position acquires Pool {
        let pool = borrow_global<Pool<CoinA, CoinB>>(pool_address);
        if (!table::contains<u64, Position>(&pool.positions, position_index)) {
            abort E_POSITION_NOT_FOUND
        };
        *table::borrow<u64, Position>(&pool.positions, position_index)
    }

    #[view]
    public fun get_position_tick_range<CoinA, CoinB>(
        pool_address: address,
        position_index: u64
    ): (I64, I64) acquires Pool {
        let pool = borrow_global<Pool<CoinA, CoinB>>(pool_address);
        if (!table::contains<u64, Position>(&pool.positions, position_index)) {
            abort E_POSITION_NOT_FOUND
        };
        let position = table::borrow<u64, Position>(&pool.positions, position_index);
        (position.tick_lower_index, position.tick_upper_index)
    }

    public fun get_position_tick_range_by_pool<CoinA, CoinB>(
        pool: &Pool<CoinA, CoinB>,
        position_index: u64
    ): (I64, I64) {
        if (!table::contains<u64, Position>(&pool.positions, position_index)) {
            abort E_POSITION_NOT_FOUND
        };
        let position = table::borrow<u64, Position>(&pool.positions, position_index);
        (position.tick_lower_index, position.tick_upper_index)
    }

    fun get_reward_in_tick_range<CoinA, CoinB>(
        pool: &Pool<CoinA, CoinB>,
        tick_lower: I64,
        tick_upper: I64
    ): vector<u128> {
        let lower_tick_option = borrow_tick<CoinA, CoinB>(pool, tick_lower);
        let upper_tick_option = borrow_tick<CoinA, CoinB>(pool, tick_upper);
        let current_tick_index = pool.current_tick_index;
        let rewards_vec = vector::empty<u128>();
        let rewarder_idx = 0;
        while (rewarder_idx < vector::length<Rewarder>(&pool.rewarder_infos)) {
            let rewarder_growth_globals = vector::borrow<Rewarder>(&pool.rewarder_infos, rewarder_idx).growth_global;
            let lower_growth = if (option::is_none<Tick>(&lower_tick_option)) {
                rewarder_growth_globals
            } else if (i64::lt(current_tick_index, tick_lower)) {
                math_u128::wrapping_sub(
                    rewarder_growth_globals,
                    *vector::borrow<u128>(
                        &option::borrow<Tick>(&lower_tick_option).rewarders_growth_outside,
                        rewarder_idx
                    )
                )
            } else {
                *vector::borrow<u128>(&option::borrow<Tick>(&lower_tick_option).rewarders_growth_outside, rewarder_idx)
            };
            let upper_growth = if (option::is_none<Tick>(&upper_tick_option)) {
                0
            } else if (i64::lt(current_tick_index, tick_upper)) {
                *vector::borrow<u128>(&option::borrow<Tick>(&upper_tick_option).rewarders_growth_outside, rewarder_idx)
            } else {
                math_u128::wrapping_sub(
                    rewarder_growth_globals,
                    *vector::borrow<u128>(
                        &option::borrow<Tick>(&upper_tick_option).rewarders_growth_outside,
                        rewarder_idx
                    )
                )
            };
            vector::push_back<u128>(
                &mut rewards_vec,
                math_u128::wrapping_sub(math_u128::wrapping_sub(rewarder_growth_globals, lower_growth), upper_growth)
            );
            rewarder_idx = rewarder_idx + 1;
        };
        rewards_vec
    }

    #[view]
    public fun get_rewarder_len<CoinA, CoinB>(pool_address: address): u8 acquires Pool {
        (vector::length<Rewarder>(&borrow_global<Pool<CoinA, CoinB>>(pool_address).rewarder_infos) as u8)
    }

    #[view]
    public fun get_tick_spacing<CoinA, CoinB>(pool_address: address): u64 acquires Pool {
        if (!exists<Pool<CoinA, CoinB>>(pool_address)) {
            abort E_POOL_NOT_EXISTS
        };
        borrow_global<Pool<CoinA, CoinB>>(pool_address).tick_spacing
    }

    public fun initialize_rewarder<CoinA, CoinB, T2>(
        account: &signer,
        pool_address: address,
        authority: address,
        rewarder_index: u64
    ) acquires Pool {
        config::assert_protocol_authority(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        let rewarder_infos = &mut pool.rewarder_infos;
        assert!(
            vector::length<Rewarder>(rewarder_infos) == rewarder_index && rewarder_index < MAX_REWARDERS,
            E_INVALID_REWARDER_INDEX
        );
        let rewarder = Rewarder {
            coin_type: type_info::type_of<T2>(),
            authority: authority,
            pending_authority: @0x0,
            emissions_per_second: 0,
            growth_global: 0,
        };
        vector::push_back<Rewarder>(rewarder_infos, rewarder);
        if (!coin::is_account_registered<T2>(pool_address)) {
            let signer_cap = account::create_signer_with_capability(&pool.signer_cap);
            coin::register<T2>(&signer_cap);
        };
    }

    fun new_empty_position(
        pool_address: address,
        tick_lower_index: I64,
        tick_upper_index: I64,
        position_index: u64
    ): Position {
        let position_rewarder_a = PositionRewarder {
            growth_inside: 0,
            amount_owed: 0,
        };
        let position_rewarder_b = PositionRewarder {
            growth_inside: 0,
            amount_owed: 0,
        };
        let position_rewarder_c = PositionRewarder {
            growth_inside: 0,
            amount_owed: 0,
        };
        let rewarder_vec = vector::empty<PositionRewarder>();
        vector::push_back<PositionRewarder>(&mut rewarder_vec, position_rewarder_a);
        vector::push_back<PositionRewarder>(&mut rewarder_vec, position_rewarder_b);
        vector::push_back<PositionRewarder>(&mut rewarder_vec, position_rewarder_c);
        Position {
            pool: pool_address,
            index: position_index,
            liquidity: 0,
            tick_lower_index: tick_lower_index,
            tick_upper_index: tick_upper_index,
            fee_growth_inside_a: 0,
            fee_owed_a: 0,
            fee_growth_inside_b: 0,
            fee_owed_b: 0,
            rewarder_infos: rewarder_vec,
        }
    }

    public fun open_position<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        tick_lower_index: I64,
        tick_upper_index: I64
    ): u64 acquires Pool {
        assert!(i64::lt(tick_lower_index, tick_upper_index), E_INVALID_TICK_INDEX);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        assert!(tick_math::is_valid_index(tick_lower_index, pool.tick_spacing), E_INVALID_TICK_INDEX);
        assert!(tick_math::is_valid_index(tick_upper_index, pool.tick_spacing), E_INVALID_TICK_INDEX);
        table::add<u64, Position>(
            &mut pool.positions,
            pool.position_index,
            new_empty_position(pool_address, tick_lower_index, tick_upper_index, pool.position_index)
        );
        let signer_cap = account::create_signer_with_capability(&pool.signer_cap);

        // position_nft::mint(account,&signer_cap,pool.index, pool.position_index, pool.uri, pool.collection_name);
        position_nft::mint(&signer_cap,account,pool.index, pool.position_index, pool.uri, pool.collection_name);
        
        let open_position_event = OpenPositionEvent {
            user: signer::address_of(account),
            pool: pool_address,
            tick_lower: tick_lower_index,
            tick_upper: tick_upper_index,
            position_index: pool.position_index,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<OpenPositionEvent>(open_position_event);
        let position_index = pool.position_index;
        pool.position_index = pool.position_index + 1;
        position_index
    }

    public fun pause<CoinA, CoinB>(account: &signer, pool_address: address) acquires Pool {
        config::assert_protocol_status();
        config::assert_protocol_authority(account);
        borrow_global_mut<Pool<CoinA, CoinB>>(pool_address).is_pause = true;
    }

    public fun remove_liquidity<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        liquidity: u128,
        position_index: u64
    ): (coin::Coin<CoinA>, coin::Coin<CoinB>) acquires Pool {
        assert!(liquidity != 0, E_ZERO_LIQUIDITY);
        check_position_authority<CoinA, CoinB>(account, pool_address, position_index);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        update_rewarder<CoinA, CoinB>(pool);
        let (tick_lower, tick_upper) = get_position_tick_range_by_pool<CoinA, CoinB>(pool, position_index);
        let (fee_growth_inside_a, fee_growth_inside_b) = get_fee_in_tick_range<CoinA, CoinB>(
            pool,
            tick_lower,
            tick_upper
        );
        let reward_in_tick_range = get_reward_in_tick_range<CoinA, CoinB>(pool, tick_lower, tick_upper);
        let position = table::borrow_mut<u64, Position>(&mut pool.positions, position_index);
        update_position_fee_and_reward(position, fee_growth_inside_a, fee_growth_inside_b, reward_in_tick_range);
        update_position_liquidity(position, liquidity, false);
        upsert_tick_by_liquidity<CoinA, CoinB>(pool, tick_lower, liquidity, false, false);
        upsert_tick_by_liquidity<CoinA, CoinB>(pool, tick_upper, liquidity, false, true);
        let (amount_a, amount_b) = clmm_math::get_amount_by_liquidity(
            tick_lower,
            tick_upper,
            pool.current_tick_index,
            pool.current_sqrt_price,
            liquidity,
            false
        );
        let (new_liquidity, is_overflow) = if (i64::lte(tick_lower, pool.current_tick_index) && i64::lt(
            pool.current_tick_index,
            tick_upper
        )) {
            math_u128::overflowing_sub(pool.liquidity, liquidity)
        } else {
            (pool.liquidity, false)
        };
        if (is_overflow) {
            abort E_OVERFLOW
        };
        pool.liquidity = new_liquidity;
        let remove_liquidity_event = RemoveLiquidityEvent {
            pool_address: pool_address,
            tick_lower: tick_lower,
            tick_upper: tick_upper,
            liquidity: liquidity,
            amount_a: amount_a,
            amount_b: amount_b,
            position_index: position_index,
            vault_a_amount: coin::value<CoinA>(&pool.coin_a),
            vault_b_amount: coin::value<CoinB>(&pool.coin_b),
            timestamp: timestamp::now_seconds(),
        };
        event::emit<RemoveLiquidityEvent>(remove_liquidity_event);
        (coin::extract<CoinA>(&mut pool.coin_a, amount_a), coin::extract<CoinB>(&mut pool.coin_b, amount_b))
    }

    fun remove_tick<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>, tick_index: I64) {
        let (tick_indexes_key, bit_index) = tick_position(tick_index, pool.tick_spacing);
        if (!table::contains<u64, BitVector>(&pool.tick_indexes, tick_indexes_key)) {
            abort E_TICK_INDEX_NOT_FOUND
        };
        bit_vector::unset(table::borrow_mut<u64, BitVector>(&mut pool.tick_indexes, tick_indexes_key), bit_index);
        if (!table::contains<I64, Tick>(&pool.ticks, tick_index)) {
            abort E_TICK_NOT_FOUND
        };
        table::remove<I64, Tick>(&mut pool.ticks, tick_index);
    }

    public fun repay_add_liquidity<CoinA, CoinB>(
        coin_a: coin::Coin<CoinA>,
        coin_b: coin::Coin<CoinB>,
        receipt_lq: AddLiquidityReceipt<CoinA, CoinB>
    ) acquires Pool {
        let AddLiquidityReceipt<CoinA, CoinB> {
            pool_address : pool_address,
            amount_a     : amount_a,
            amount_b     : amount_b,
        } = receipt_lq;
        assert!(coin::value<CoinA>(&coin_a) == amount_a, E_AMOUNT_MISMATCH);
        assert!(coin::value<CoinB>(&coin_b) == amount_b, E_AMOUNT_MISMATCH);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        coin::merge<CoinA>(&mut pool.coin_a, coin_a);
        coin::merge<CoinB>(&mut pool.coin_b, coin_b);
    }

    public fun repay_flash_swap<CoinA, CoinB>(
        coin_a: coin::Coin<CoinA>,
        coin_b: coin::Coin<CoinB>,
        receipt_swap: FlashSwapReceipt<CoinA, CoinB>
    ) acquires Pool {
        let FlashSwapReceipt<CoinA, CoinB> {
            pool_address   : pool_address,
            a2b            : a2b,
            partner_name   : partner_name,
            pay_amount     : pay_amount,
            ref_fee_amount : ref_fee_amount,
        } = receipt_swap;
        if (a2b) {
            assert!(coin::value<CoinA>(&coin_a) == pay_amount, E_AMOUNT_MISMATCH);
            if (ref_fee_amount > 0) {
                partner::receive_ref_fee<CoinA>(partner_name, coin::extract<CoinA>(&mut coin_a, ref_fee_amount));
            };
            coin::merge<CoinA>(&mut borrow_global_mut<Pool<CoinA, CoinB>>(pool_address).coin_a, coin_a);
            coin::destroy_zero<CoinB>(coin_b);
        } else {
            assert!(coin::value<CoinB>(&coin_b) == pay_amount, E_AMOUNT_MISMATCH);
            if (ref_fee_amount > 0) {
                partner::receive_ref_fee<CoinB>(partner_name, coin::extract<CoinB>(&mut coin_b, ref_fee_amount));
            };
            coin::merge<CoinB>(&mut borrow_global_mut<Pool<CoinA, CoinB>>(pool_address).coin_b, coin_b);
            coin::destroy_zero<CoinA>(coin_a);
        };
    }

    public fun reset_init_price<CoinA, CoinB>(_pool_address: address, _tick_index: u128) {
        abort E_RESET_INIT_PRICE_DISABLED
    }

    public fun reset_init_price_v2<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        sqrt_price: u128
    ) acquires Pool {
        config::assert_reset_init_price_authority(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert!(
            sqrt_price > tick_math::get_sqrt_price_at_tick(
                tick_min(pool.tick_spacing)
            ) && sqrt_price < tick_math::get_sqrt_price_at_tick(tick_max(pool.tick_spacing)),
            E_INVALID_SQRT_PRICE
        );
        assert!(pool.position_index == 1, E_POOL_NOT_EMPTY);
        pool.current_sqrt_price = sqrt_price;
        pool.current_tick_index = tick_math::get_tick_at_sqrt_price(sqrt_price);
    }

    fun rewarder_growth_globals(rewarders: vector<Rewarder>): vector<u128> {
        let growth_globals = vector[0, 0, 0];
        let count = 0;
        while (count < vector::length<Rewarder>(&rewarders)) {
            *vector::borrow_mut<u128>(&mut growth_globals, count) = vector::borrow<Rewarder>(
                &rewarders,
                count
            ).growth_global;
            count = count + 1;
        };
        growth_globals
    }

    fun swap_in_pool<CoinA, CoinB>(
        pool: &mut Pool<CoinA, CoinB>,
        a2b: bool,
        by_amount_in: bool,
        sqrt_price_limit: u128,
        amount: u64,
        protocol_fee_rate: u64,
        ref_fee_rate: u64
    ): SwapResult {
        let swap_in_pool = default_swap_result();
        let current_tick_index = pool.current_tick_index;
        let max_tick = tick_max(pool.tick_spacing);
        while (amount > 0 && pool.current_sqrt_price != sqrt_price_limit) {
            if (i64::gt(current_tick_index, max_tick) || i64::lt(current_tick_index, tick_min(pool.tick_spacing))) {
                abort E_SWAP_OUT_OF_RANGE
            };
            let next_tick_option = get_next_tick_for_swap<CoinA, CoinB>(pool, current_tick_index, a2b, max_tick);
            if (option::is_none<Tick>(&next_tick_option)) {
                abort E_SWAP_OUT_OF_RANGE
            };
            let next_tick = option::destroy_some<Tick>(next_tick_option);
            let target_sqrt_price = if (a2b) {
                math_u128::max(sqrt_price_limit, next_tick.sqrt_price)
            } else {
                math_u128::min(sqrt_price_limit, next_tick.sqrt_price)
            };
            let (amount_in, amount_out, next_sqrt_price, fee_amount) = clmm_math::compute_swap_step(
                pool.current_sqrt_price,
                target_sqrt_price,
                pool.liquidity,
                amount,
                pool.fee_rate,
                a2b,
                by_amount_in
            );
            if (amount_in != 0 || fee_amount != 0) {
                if (by_amount_in) {
                    let sub_remainer_amount = check_sub_remainer_amount(amount, amount_in);
                    amount = check_sub_remainer_amount(sub_remainer_amount, fee_amount);
                } else {
                    amount = check_sub_remainer_amount(amount, amount_out);
                };
                update_swap_result(&mut swap_in_pool, amount_in, amount_out, fee_amount);
                swap_in_pool.ref_fee_amount = update_pool_fee<CoinA, CoinB>(
                    pool,
                    fee_amount,
                    ref_fee_rate,
                    protocol_fee_rate,
                    a2b
                );
            };
            if (next_sqrt_price == next_tick.sqrt_price) {
                pool.current_sqrt_price = next_tick.sqrt_price;
                let new_tick_index = if (a2b) {
                    i64::sub(next_tick.index, i64::from(1))
                } else {
                    next_tick.index
                };
                pool.current_tick_index = new_tick_index;
                cross_tick_and_update_liquidity<CoinA, CoinB>(pool, next_tick.index, a2b);
            } else {
                pool.current_sqrt_price = next_sqrt_price;
                pool.current_tick_index = tick_math::get_tick_at_sqrt_price(next_sqrt_price);
            };
            if (a2b) {
                current_tick_index = i64::sub(next_tick.index, i64::from(1));
                continue
            };
            current_tick_index = next_tick.index;
        };
        swap_in_pool
    }

    public fun swap_pay_amount<CoinA, CoinB>(receipt_swap: &FlashSwapReceipt<CoinA, CoinB>): u64 {
        receipt_swap.pay_amount
    }

    fun tick_indexes_index(tick_index: I64, tick_spacing: u64): u64 {
        let offset = i64::sub(tick_index, tick_min(tick_spacing));
        if (i64::is_neg(offset)) {
            abort E_NEGATIVE_TICK_OFFSET
        };
        i64::as_u64(offset) / (tick_spacing * TICK_INDEX_GROUP_SIZE)
    }

    fun tick_indexes_max(tick_spacing: u64): u64 {
        (tick_math::tick_bound() * 2) / (tick_spacing * TICK_INDEX_GROUP_SIZE) + 1
    }

    fun tick_max(tick_spacing: u64): I64 {
        let max_tick = tick_math::max_tick();
        i64::sub(max_tick, i64::mod(max_tick, i64::from(tick_spacing)))
    }

    fun tick_min(tick_spacing: u64): I64 {
        let min_tick = tick_math::min_tick();
        i64::sub(min_tick, i64::mod(min_tick, i64::from(tick_spacing)))
    }

    fun tick_offset(tick_index_key: u64, tick_spacing: u64, tick_index: I64): u64 {
        (i64::as_u64(
            i64::add(tick_index, tick_max(tick_spacing))
        ) - tick_index_key * tick_spacing * TICK_INDEX_GROUP_SIZE) / tick_spacing
    }

    fun tick_position(tick_index: I64, tick_spacing: u64): (u64, u64) {
        let tick_index_key = tick_indexes_index(tick_index, tick_spacing);
        (tick_index_key, (i64::as_u64(
            i64::add(tick_index, tick_max(tick_spacing))
        ) - tick_index_key * tick_spacing * TICK_INDEX_GROUP_SIZE) / tick_spacing)
    }

    public fun transfer_rewarder_authority<CoinA, CoinB>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8,
        new_authority: address
    ) acquires Pool {
        let old_authority = signer::address_of(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        assert!((rewarder_index as u64) < vector::length<Rewarder>(&pool.rewarder_infos), E_INVALID_REWARDER_INDEX);
        let rewarder_vec = vector::borrow_mut<Rewarder>(&mut pool.rewarder_infos, (rewarder_index as u64));
        assert!(rewarder_vec.authority == old_authority, E_NOT_AUTHORITY);
        rewarder_vec.pending_authority = new_authority;
        let transfer_reward_event = TransferRewardAuthEvent {
            pool_address: pool_address,
            rewarder_index: rewarder_index,
            old_authority: old_authority,
            new_authority: new_authority,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<TransferRewardAuthEvent>(transfer_reward_event);
    }

    public fun unpause<CoinA, CoinB>(account: &signer, pool_address: address) acquires Pool {
        config::assert_protocol_status();
        config::assert_protocol_authority(account);
        borrow_global_mut<Pool<CoinA, CoinB>>(pool_address).is_pause = false;
    }

    public fun update_emission<CoinA, CoinB, T2>(
        account: &signer,
        pool_address: address,
        rewarder_index: u8,
        emissions_per_second: u128
    ) acquires Pool {
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        update_rewarder<CoinA, CoinB>(pool);
        assert!((rewarder_index as u64) < vector::length<Rewarder>(&pool.rewarder_infos), E_INVALID_REWARDER_INDEX);
        let rewarder_vec = vector::borrow_mut<Rewarder>(&mut pool.rewarder_infos, (rewarder_index as u64));
        assert!(signer::address_of(account) == rewarder_vec.authority, E_NOT_AUTHORITY);
        assert!(rewarder_vec.coin_type == type_info::type_of<T2>(), E_REWARDER_TYPE_MISMATCH);
        assert!(
            coin::balance<T2>(pool_address) >= (full_math_u128::mul_shr(86400, emissions_per_second, 64) as u64),
            E_INSUFFICIENT_REWARD_BALANCE
        );
        rewarder_vec.emissions_per_second = emissions_per_second;
        let emission_update_event = UpdateEmissionEvent {
            pool_address: pool_address,
            rewarder_index: rewarder_index,
            emissions_per_second: emissions_per_second,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateEmissionEvent>(emission_update_event);
    }

    public fun update_fee_rate<CoinA, CoinB>(account: &signer, pool_address: address, new_fee_rate: u64) acquires Pool {
        if (new_fee_rate > fee_tier::max_fee_rate()) {
            abort E_FEE_RATE_TOO_HIGH
        };
        config::assert_protocol_authority(account);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        assert_status<CoinA, CoinB>(pool);
        pool.fee_rate = new_fee_rate;
        let update_feerate_event = UpdateFeeRateEvent {
            pool_address: pool_address,
            old_fee_rate: pool.fee_rate,
            new_fee_rate: new_fee_rate,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateFeeRateEvent>(update_feerate_event);
    }

    fun update_pool_fee<CoinA, CoinB>(
        pool: &mut Pool<CoinA, CoinB>,
        fee_amount: u64,
        ref_fee_rate: u64,
        protocol_fee_rate: u64,
        a2b: bool
    ): u64 {
        let protocol_fee = full_math_u64::mul_div_ceil(fee_amount, protocol_fee_rate, PROTOCOL_FEE_DENOMINATOR);
        let liquidity_fee = fee_amount - protocol_fee;
        let ref_fee = if (ref_fee_rate == 0) {
            0
        } else {
            full_math_u64::mul_div_floor(protocol_fee, ref_fee_rate, PROTOCOL_FEE_DENOMINATOR)
        };
        if (a2b) {
            pool.fee_protocol_coin_a = math_u64::wrapping_add(pool.fee_protocol_coin_a, protocol_fee - ref_fee);
        } else {
            pool.fee_protocol_coin_b = math_u64::wrapping_add(pool.fee_protocol_coin_b, protocol_fee - ref_fee);
        };
        if (liquidity_fee == 0 || pool.liquidity == 0) {
            return ref_fee
        };
        if (a2b) {
            pool.fee_growth_global_a = math_u128::wrapping_add(
                pool.fee_growth_global_a,
                ((liquidity_fee as u128) << 64) / pool.liquidity
            );
        } else {
            pool.fee_growth_global_b = math_u128::wrapping_add(
                pool.fee_growth_global_b,
                ((liquidity_fee as u128) << 64) / pool.liquidity
            );
        };
        ref_fee
    }

    public fun update_pool_uri<CoinA, CoinB>(account: &signer, pool_address: address, new_uri: String) acquires Pool {
        assert!(!string::is_empty(&new_uri), E_EMPTY_URI);
        assert!(config::allow_set_position_nft_uri(account), E_NOT_ALLOWED_SET_NFT_URI);
        let pool = borrow_global_mut<Pool<CoinA, CoinB>>(pool_address);
        let signer_cap = account::create_signer_with_capability(&pool.signer_cap);
        position_nft::mutate_collection_uri(&signer_cap, pool.collection_name, new_uri);
        pool.uri = new_uri;
    }

    fun update_position_fee(position: &mut Position, new_fee_growth_inside_a: u128, new_fee_growth_inside_b: u128) {
        let (updated_fee_owed_a, overflow_a) = math_u64::overflowing_add(
            position.fee_owed_a,
            (full_math_u128::mul_shr(
                position.liquidity,
                math_u128::wrapping_sub(new_fee_growth_inside_a, position.fee_growth_inside_a),
                64
            ) as u64)
        );
        let (updated_fee_owed_b, overflow_b) = math_u64::overflowing_add(
            position.fee_owed_b,
            (full_math_u128::mul_shr(
                position.liquidity,
                math_u128::wrapping_sub(new_fee_growth_inside_b, position.fee_growth_inside_b),
                64
            ) as u64)
        );
        assert!(!overflow_a, E_OVERFLOW_FEE_OWED);
        assert!(!overflow_b, E_OVERFLOW_FEE_OWED);
        position.fee_owed_a = updated_fee_owed_a;
        position.fee_owed_b = updated_fee_owed_b;
        position.fee_growth_inside_a = new_fee_growth_inside_a;
        position.fee_growth_inside_b = new_fee_growth_inside_b;
    }

    fun update_position_fee_and_reward(
        position: &mut Position,
        new_fee_growth_inside_a: u128,
        new_fee_growth_inside_b: u128,
        new_reward_growths: vector<u128>
    ) {
        update_position_fee(position, new_fee_growth_inside_a, new_fee_growth_inside_b);
        update_position_rewarder(position, new_reward_growths);
    }

    fun update_position_liquidity(position: &mut Position, liquidity_delta: u128, is_add: bool) {
        if (liquidity_delta == 0) {
            return
        };
        let (new_liquidity, overflow) = if (is_add) {
            math_u128::overflowing_add(position.liquidity, liquidity_delta)
        } else {
            math_u128::overflowing_sub(position.liquidity, liquidity_delta)
        };
        assert!(!overflow, E_OVERFLOW_POSITION_LIQUIDITY);
        position.liquidity = new_liquidity;
    }

    fun update_position_rewarder(position: &mut Position, new_growths: vector<u128>) {
        let count = 0;
        while (count < vector::length<u128>(&new_growths)) {
            let new_growth = *vector::borrow<u128>(&new_growths, count);
            let rewarder = vector::borrow_mut<PositionRewarder>(&mut position.rewarder_infos, count);
            rewarder.growth_inside = new_growth;
            let (new_amount_owed, overflow) = math_u64::overflowing_add(
                rewarder.amount_owed,
                (full_math_u128::mul_shr(
                    math_u128::wrapping_sub(new_growth, rewarder.growth_inside),
                    position.liquidity,
                    64
                ) as u64)
            );
            assert!(!overflow, E_OVERFLOW_REWARD_AMOUNT);
            rewarder.amount_owed = new_amount_owed;
            count = count + 1;
        };
    }

    fun update_rewarder<CoinA, CoinB>(pool: &mut Pool<CoinA, CoinB>) {
        let time = timestamp::now_seconds();
        let last_update_time = pool.rewarder_last_updated_time;
        pool.rewarder_last_updated_time = time;
        assert!(last_update_time <= time, E_INVALID_TIMESTAMP);
        if (pool.liquidity == 0 || time == last_update_time) {
            return
        };
        let count = 0;
        while (count < vector::length<Rewarder>(&pool.rewarder_infos)) {
            vector::borrow_mut<Rewarder>(&mut pool.rewarder_infos, count).growth_global = vector::borrow<Rewarder>(
                &pool.rewarder_infos,
                count
            ).growth_global + full_math_u128::mul_div_floor(
                ((time - last_update_time) as u128),
                vector::borrow<Rewarder>(&pool.rewarder_infos, count).emissions_per_second,
                pool.liquidity
            );
            count = count + 1;
        };
    }

    fun update_swap_result(swap_result: &mut SwapResult, amount_in: u64, amount_out: u64, fee_amount: u64) {
        let (new_amount_in, overflow_in) = math_u64::overflowing_add(swap_result.amount_in, amount_in);
        if (overflow_in) {
            abort E_OVERFLOW_AMOUNT_IN
        };
        let (new_amount_out, overflow_out) = math_u64::overflowing_add(swap_result.amount_out, amount_out);
        if (overflow_out) {
            abort E_OVERFLOW_AMOUNT_OUT
        };
        let (new_fee_amount, overflow_fee) = math_u64::overflowing_add(swap_result.fee_amount, fee_amount);
        if (overflow_fee) {
            abort E_OVERFLOW_FEE_AMOUNT
        };
        swap_result.amount_out = new_amount_out;
        swap_result.amount_in = new_amount_in;
        swap_result.fee_amount = new_fee_amount;
    }

    fun upsert_tick_by_liquidity<CoinA, CoinB>(
        pool: &mut Pool<CoinA, CoinB>,
        tick_index: I64,
        liquidity_delta: u128,
        is_add: bool,
        is_upper: bool
    ) {
        let tick = borrow_mut_tick_with_default(&mut pool.tick_indexes, &mut pool.ticks, pool.tick_spacing, tick_index);
        if (liquidity_delta == 0) {
            return
        };
        let (new_liduidity, overflow) = if (is_add) {
            math_u128::overflowing_add(tick.liquidity_gross, liquidity_delta)
        } else {
            math_u128::overflowing_sub(tick.liquidity_gross, liquidity_delta)
        };
        if (overflow) {
            abort E_OVERFLOW
        };
        if (new_liduidity == 0) {
            remove_tick<CoinA, CoinB>(pool, tick_index);
            return
        };
        let (fee_growth_outside_a, fee_growth_outside_b, rewarders_growth_outside) = if (tick.liquidity_gross == 0) {
            if (i64::gte(pool.current_tick_index, tick_index)) {
                (pool.fee_growth_global_a, pool.fee_growth_global_b, rewarder_growth_globals(pool.rewarder_infos))
            } else {
                (0, 0, vector[0, 0, 0])
            }
        } else {
            (tick.fee_growth_outside_a, tick.fee_growth_outside_b, tick.rewarders_growth_outside)
        };
        let (new_liquidity_net, overflow_net) = if (is_add) {
            let (liquidity_net, overflow) = if (is_upper) {
                let (diff, overflow) = i128::overflowing_sub(tick.liquidity_net, i128::from(liquidity_delta));
                (overflow, diff)
            } else {
                let (sum, overflow) = i128::overflowing_add(tick.liquidity_net, i128::from(liquidity_delta));
                (overflow, sum)
            };
            (overflow, liquidity_net)
        } else if (is_upper) {
            i128::overflowing_add(tick.liquidity_net, i128::from(liquidity_delta))
        } else {
            i128::overflowing_sub(tick.liquidity_net, i128::from(liquidity_delta))
        };
        if (overflow_net) {
            abort E_OVERFLOW
        };
        tick.liquidity_gross = new_liduidity;
        tick.liquidity_net = new_liquidity_net;
        tick.fee_growth_outside_a = fee_growth_outside_a;
        tick.fee_growth_outside_b = fee_growth_outside_b;
        tick.rewarders_growth_outside = rewarders_growth_outside;
    }

    // decompiled from Move bytecode v6
}