module dexlyn_clmm::clmm_math {

    use dexlyn_clmm::tick_math;
    use integer_mate::full_math_u128;
    use integer_mate::full_math_u64;
    use integer_mate::i64;
    use integer_mate::math_u128;
    use integer_mate::math_u256;
    use integer_mate::u256;

    /// token amount exceeds the maximum allowed value
    const E_TOKEN_AMOUNT_MAX_EXCEEDED: u64 = 1;

    /// token amount is below the minimum allowed value
    const E_TOKEN_AMOUNT_MIN_SUBCEEDED: u64 = 2;

    /// multiplication overflows in math operations
    const E_MULTIPLICATION_OVERFLOW: u64 = 3;

    /// invalid sqrt price is provided as input
    const E_INVALID_SQRT_PRICE_INPUT: u64 = 4;

    /// function or feature is not implemented
    const E_NOT_IMPLEMENTED: u64 = 5;

    /// tick index is out of the allowed range
    const E_TICK_INDEX_OUT_OF_RANGE: u64 = 6;

    const FEE_RATE_DENOMINATOR: u64 = 1000000;

    #[view]
    public fun compute_swap_step(
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        liquidity: u128,
        amount: u64,
        fee_rate: u64,
        a2b: bool,
        by_amount_in: bool
    ): (u64, u64, u128, u64) {
        if (liquidity == 0) {
            return (0, 0, target_sqrt_price, 0)
        };
        if (a2b) {
            assert!(current_sqrt_price >= target_sqrt_price, E_INVALID_SQRT_PRICE_INPUT);
        } else {
            assert!(current_sqrt_price < target_sqrt_price, E_INVALID_SQRT_PRICE_INPUT);
        };
        let (amount_in, amount_out, fee_amount, next_sqrt_price) = if (by_amount_in) {
            let amount_remain = full_math_u64::mul_div_floor(
                amount,
                FEE_RATE_DENOMINATOR - fee_rate,
                FEE_RATE_DENOMINATOR
            );
            let max_amount_in = get_delta_up_from_input_v2(current_sqrt_price, target_sqrt_price, liquidity, a2b);
            let (amount_in, fee_amount, next_sqrt_price) = if (max_amount_in > (amount_remain as u256)) {
                (amount_remain, amount - amount_remain, get_next_sqrt_price_from_input(
                    current_sqrt_price,
                    liquidity,
                    amount_remain,
                    a2b
                ))
            } else {
                let amount_in = (max_amount_in as u64);
                (amount_in, full_math_u64::mul_div_ceil(
                    amount_in,
                    fee_rate,
                    FEE_RATE_DENOMINATOR - fee_rate
                ), target_sqrt_price)
            };
            (amount_in, (get_delta_down_from_output_v2(
                current_sqrt_price,
                next_sqrt_price,
                liquidity,
                a2b
            ) as u64), fee_amount, next_sqrt_price)
        } else {
            let max_amount_out = get_delta_down_from_output_v2(current_sqrt_price, target_sqrt_price, liquidity, a2b);
            let (amount_out, next_sqrt_price) = if (max_amount_out > (amount as u256)) {
                (amount, get_next_sqrt_price_from_output(current_sqrt_price, liquidity, amount, a2b))
            } else {
                ((max_amount_out as u64), target_sqrt_price)
            };
            let amount_in = (get_delta_up_from_input_v2(current_sqrt_price, next_sqrt_price, liquidity, a2b) as u64);
            (amount_in, amount_out, full_math_u64::mul_div_ceil(
                amount_in,
                fee_rate,
                FEE_RATE_DENOMINATOR - fee_rate
            ), next_sqrt_price)
        };
        (amount_in, amount_out, next_sqrt_price, fee_amount)
    }

    #[view]
    public fun fee_rate_denominator(): u64 {
        FEE_RATE_DENOMINATOR
    }

    public fun get_amount_by_liquidity(
        tick_lower: i64::I64,
        tick_upper: i64::I64,
        current_tick_index: i64::I64,
        current_sqrt_price: u128,
        liquidity: u128,
        round_up: bool
    ): (u64, u64) {
        if (liquidity == 0) {
            return (0, 0)
        };
        if (i64::lt(current_tick_index, tick_lower)) {
            (get_delta_a(
                tick_math::get_sqrt_price_at_tick(tick_lower),
                tick_math::get_sqrt_price_at_tick(tick_upper),
                liquidity,
                round_up
            ), 0)
        } else if (i64::lt(current_tick_index, tick_upper)) {
            (get_delta_a(
                current_sqrt_price,
                tick_math::get_sqrt_price_at_tick(tick_upper),
                liquidity,
                round_up
            ), get_delta_b(tick_math::get_sqrt_price_at_tick(tick_lower), current_sqrt_price, liquidity, round_up))
        } else {
            (0, get_delta_b(
                tick_math::get_sqrt_price_at_tick(tick_lower),
                tick_math::get_sqrt_price_at_tick(tick_upper),
                liquidity,
                round_up
            ))
        }
    }

    #[view]
    public fun get_delta_a(sqrt_price_0: u128, sqrt_price_1: u128, liquidity: u128, round_up: bool): u64 {
        let sqrt_price_diff = if (sqrt_price_0 > sqrt_price_1) {
            sqrt_price_0 - sqrt_price_1
        } else {
            sqrt_price_1 - sqrt_price_0
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        let (numerator, overflowing) = math_u256::checked_shlw(full_math_u128::full_mul_v2(liquidity, sqrt_price_diff));
        if (overflowing) {
            abort E_MULTIPLICATION_OVERFLOW
        };
        (math_u256::div_round(numerator, full_math_u128::full_mul_v2(sqrt_price_0, sqrt_price_1), round_up) as u64)
    }

    #[view]
    public fun get_delta_b(sqrt_price_0: u128, sqrt_price_1: u128, liquidity: u128, round_up: bool): u64 {
        let sqrt_price_diff = if (sqrt_price_0 > sqrt_price_1) {
            sqrt_price_0 - sqrt_price_1
        } else {
            sqrt_price_1 - sqrt_price_0
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        let product = full_math_u128::full_mul_v2(liquidity, sqrt_price_diff);
        if (round_up && product & 18446744073709551615 > 0) {
            return (((product >> 64) + 1) as u64)
        };
        ((product >> 64) as u64)
    }

    public fun get_delta_down_from_output(
        _current_sqrt_price: u128,
        _target_sqrt_price: u128,
        _liquidity: u128,
        _a_to_b: bool
    ): u256::U256 {
        abort E_NOT_IMPLEMENTED
    }

    #[view]
    public fun get_delta_down_from_output_v2(
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        liquidity: u128,
        a_to_b: bool
    ): u256 {
        let sqrt_price_diff = if (current_sqrt_price > target_sqrt_price) {
            current_sqrt_price - target_sqrt_price
        } else {
            target_sqrt_price - current_sqrt_price
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        if (a_to_b) {
            full_math_u128::full_mul_v2(liquidity, sqrt_price_diff) >> 64
        } else {
            let (numerator, overflowing) = math_u256::checked_shlw(
                full_math_u128::full_mul_v2(liquidity, sqrt_price_diff)
            );
            if (overflowing) {
                abort E_MULTIPLICATION_OVERFLOW
            };
            math_u256::div_round(numerator, full_math_u128::full_mul_v2(current_sqrt_price, target_sqrt_price), false)
        }
    }

    public fun get_delta_up_from_input(
        _current_sqrt_price: u128,
        _target_sqrt_price: u128,
        _liquidity: u128,
        _a_to_b: bool
    ): u256::U256 {
        abort E_NOT_IMPLEMENTED
    }

    #[view]
    public fun get_delta_up_from_input_v2(
        current_sqrt_price: u128,
        target_sqrt_price: u128,
        liquidity: u128,
        a_to_b: bool
    ): u256 {
        let sqrt_price_diff = if (current_sqrt_price > target_sqrt_price) {
            current_sqrt_price - target_sqrt_price
        } else {
            target_sqrt_price - current_sqrt_price
        };
        if (sqrt_price_diff == 0 || liquidity == 0) {
            return 0
        };
        if (a_to_b) {
            let (numerator, overflowing) = math_u256::checked_shlw(
                full_math_u128::full_mul_v2(liquidity, sqrt_price_diff)
            );
            if (overflowing) {
                abort E_MULTIPLICATION_OVERFLOW
            };
            math_u256::div_round(numerator, full_math_u128::full_mul_v2(current_sqrt_price, target_sqrt_price), true)
        } else {
            let product = full_math_u128::full_mul_v2(liquidity, sqrt_price_diff);
            if (product & 18446744073709551615 > 0) {
                return (product >> 64) + 1
            };
            product >> 64
        }
    }

    #[view]
    public fun get_liquidity_from_a(sqrt_price_0: u128, sqrt_price_1: u128, amount_a: u64, round_up: bool): u128 {
        let sqrt_price_diff = if (sqrt_price_0 > sqrt_price_1) {
            sqrt_price_0 - sqrt_price_1
        } else {
            sqrt_price_1 - sqrt_price_0
        };
        (math_u256::div_round(
            (full_math_u128::full_mul_v2(sqrt_price_0, sqrt_price_1) >> 64) * (amount_a as u256),
            (sqrt_price_diff as u256),
            round_up
        ) as u128)
    }

    public fun get_liquidity_from_amount(
        lower_index: i64::I64,
        upper_index: i64::I64,
        current_tick_index: i64::I64,
        current_sqrt_price: u128,
        amount: u64,
        is_fixed_a: bool
    ): (u128, u64, u64) {
        let amount_a = 0;
        let amount_b = 0;
        let liquidity = if (is_fixed_a) {
            amount_a = amount;
            if (i64::lt(current_tick_index, lower_index)) {
                get_liquidity_from_a(
                    tick_math::get_sqrt_price_at_tick(lower_index),
                    tick_math::get_sqrt_price_at_tick(upper_index),
                    amount,
                    false
                )
            } else {
                assert!(i64::lt(current_tick_index, upper_index), E_TICK_INDEX_OUT_OF_RANGE);
                let liquidity = get_liquidity_from_a(
                    current_sqrt_price,
                    tick_math::get_sqrt_price_at_tick(upper_index),
                    amount,
                    false
                );
                amount_b = get_delta_b(
                    current_sqrt_price,
                    tick_math::get_sqrt_price_at_tick(lower_index),
                    liquidity,
                    true
                );
                liquidity
            }
        } else {
            amount_b = amount;
            if (i64::gte(current_tick_index, upper_index)) {
                get_liquidity_from_b(
                    tick_math::get_sqrt_price_at_tick(lower_index),
                    tick_math::get_sqrt_price_at_tick(upper_index),
                    amount,
                    false
                )
            } else {
                assert!(i64::gte(current_tick_index, lower_index), E_TICK_INDEX_OUT_OF_RANGE);
                let liquidity = get_liquidity_from_b(
                    tick_math::get_sqrt_price_at_tick(lower_index),
                    current_sqrt_price,
                    amount,
                    false
                );
                amount_a = get_delta_a(
                    current_sqrt_price,
                    tick_math::get_sqrt_price_at_tick(upper_index),
                    liquidity,
                    true
                );
                liquidity
            }
        };
        (liquidity, amount_a, amount_b)
    }

    #[view]
    public fun get_liquidity_from_b(sqrt_price_0: u128, sqrt_price_1: u128, amount_b: u64, round_up: bool): u128 {
        let sqrt_price_diff = if (sqrt_price_0 > sqrt_price_1) {
            sqrt_price_0 - sqrt_price_1
        } else {
            sqrt_price_1 - sqrt_price_0
        };
        (math_u256::div_round((amount_b as u256) << 64, (sqrt_price_diff as u256), round_up) as u128)
    }

    #[view]
    public fun get_next_sqrt_price_a_up(sqrt_price: u128, liquidity: u128, amount: u64, by_amount_input: bool): u128 {
        if (amount == 0) {
            return sqrt_price
        };
        let (numerator, overflowing) = math_u256::checked_shlw(full_math_u128::full_mul_v2(sqrt_price, liquidity));
        if (overflowing) {
            abort E_MULTIPLICATION_OVERFLOW
        };
        let new_sqrt_price = if (by_amount_input) {
            (math_u256::div_round(
                numerator,
                ((liquidity as u256) << 64) + full_math_u128::full_mul_v2(sqrt_price, (amount as u128)),
                true
            ) as u128)
        } else {
            (math_u256::div_round(
                numerator,
                ((liquidity as u256) << 64) - full_math_u128::full_mul_v2(sqrt_price, (amount as u128)),
                true
            ) as u128)
        };
        if (new_sqrt_price > tick_math::max_sqrt_price()) {
            abort E_TOKEN_AMOUNT_MAX_EXCEEDED
        };
        if (new_sqrt_price < tick_math::min_sqrt_price()) {
            abort E_TOKEN_AMOUNT_MIN_SUBCEEDED
        };
        new_sqrt_price
    }

    #[view]
    public fun get_next_sqrt_price_b_down(sqrt_price: u128, liquidity: u128, amount: u64, by_amount_input: bool): u128 {
        let new_sqrt_price = if (by_amount_input) {
            sqrt_price + math_u128::checked_div_round((amount as u128) << 64, liquidity, !by_amount_input)
        } else {
            sqrt_price - math_u128::checked_div_round((amount as u128) << 64, liquidity, !by_amount_input)
        };
        if (new_sqrt_price > tick_math::max_sqrt_price()) {
            abort E_TOKEN_AMOUNT_MAX_EXCEEDED
        };
        if (new_sqrt_price < tick_math::min_sqrt_price()) {
            abort E_TOKEN_AMOUNT_MIN_SUBCEEDED
        };
        new_sqrt_price
    }

    #[view]
    public fun get_next_sqrt_price_from_input(sqrt_price: u128, liquidity: u128, amount: u64, a_to_b: bool): u128 {
        if (a_to_b) {
            get_next_sqrt_price_a_up(sqrt_price, liquidity, amount, true)
        } else {
            get_next_sqrt_price_b_down(sqrt_price, liquidity, amount, true)
        }
    }

    #[view]
    public fun get_next_sqrt_price_from_output(sqrt_price: u128, liquidity: u128, amount: u64, a_to_b: bool): u128 {
        if (a_to_b) {
            get_next_sqrt_price_b_down(sqrt_price, liquidity, amount, false)
        } else {
            get_next_sqrt_price_a_up(sqrt_price, liquidity, amount, false)
        }
    }

    // decompiled from Move bytecode v6
}

