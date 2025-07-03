module dexlyn_clmm::tick_math {

    use integer_mate::full_math_u128;
    use integer_mate::i128;
    use integer_mate::i64::{Self, I64};

    /// the tick is out of bounds
    const E_TICK_OUT_OF_BOUNDS: u64 = 1;

    /// the sqrt price is out of bounds
    const E_SQRT_PRICE_OUT_OF_BOUNDS: u64 = 2;

    fun as_u8(data: bool): u8 {
        if (data) {
            1
        } else {
            0
        }
    }

    fun get_sqrt_price_at_negative_tick(tick: I64): u128 {
        let abs_tick = i64::as_u64(i64::abs(tick));
        let ratio = if (abs_tick & 1 != 0) {
            18445821805675392311
        } else {
            18446744073709551616
        };
        if (abs_tick & 2 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18444899583751176498, 64);
        };
        if (abs_tick & 4 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18443055278223354162, 64);
        };
        if (abs_tick & 8 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18439367220385604838, 64);
        };
        if (abs_tick & 16 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18431993317065449817, 64);
        };
        if (abs_tick & 32 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18417254355718160513, 64);
        };
        if (abs_tick & 64 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18387811781193591352, 64);
        };
        if (abs_tick & 128 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18329067761203520168, 64);
        };
        if (abs_tick & 256 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 18212142134806087854, 64);
        };
        if (abs_tick & 512 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 17980523815641551639, 64);
        };
        if (abs_tick & 1024 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 17526086738831147013, 64);
        };
        if (abs_tick & 2048 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 16651378430235024244, 64);
        };
        if (abs_tick & 4096 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 15030750278693429944, 64);
        };
        if (abs_tick & 8192 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 12247334978882834399, 64);
        };
        if (abs_tick & 16384 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 8131365268884726200, 64);
        };
        if (abs_tick & 32768 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 3584323654723342297, 64);
        };
        if (abs_tick & 65536 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 696457651847595233, 64);
        };
        if (abs_tick & 131072 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 26294789957452057, 64);
        };
        if (abs_tick & 262144 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 37481735321082, 64);
        };
        ratio
    }

    fun get_sqrt_price_at_positive_tick(tick: I64): u128 {
        let abs_tick = i64::as_u64(i64::abs(tick));
        let ratio = if (abs_tick & 1 != 0) {
            79232123823359799118286999567
        } else {
            79228162514264337593543950336
        };
        if (abs_tick & 2 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79236085330515764027303304731, 96);
        };
        if (abs_tick & 4 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79244008939048815603706035061, 96);
        };
        if (abs_tick & 8 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79259858533276714757314932305, 96);
        };
        if (abs_tick & 16 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79291567232598584799939703904, 96);
        };
        if (abs_tick & 32 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79355022692464371645785046466, 96);
        };
        if (abs_tick & 64 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79482085999252804386437311141, 96);
        };
        if (abs_tick & 128 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 79736823300114093921829183326, 96);
        };
        if (abs_tick & 256 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 80248749790819932309965073892, 96);
        };
        if (abs_tick & 512 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 81282483887344747381513967011, 96);
        };
        if (abs_tick & 1024 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 83390072131320151908154831281, 96);
        };
        if (abs_tick & 2048 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 87770609709833776024991924138, 96);
        };
        if (abs_tick & 4096 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 97234110755111693312479820773, 96);
        };
        if (abs_tick & 8192 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 119332217159966728226237229890, 96);
        };
        if (abs_tick & 16384 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 179736315981702064433883588727, 96);
        };
        if (abs_tick & 32768 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 407748233172238350107850275304, 96);
        };
        if (abs_tick & 65536 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 2098478828474011932436660412517, 96);
        };
        if (abs_tick & 131072 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 55581415166113811149459800483533, 96);
        };
        if (abs_tick & 262144 != 0) {
            ratio = full_math_u128::mul_shr(ratio, 38992368544603139932233054999993551, 96);
        };
        ratio >> 32
    }

    public fun get_sqrt_price_at_tick(tick: i64::I64): u128 {
        assert!(i64::gte(tick, min_tick()) && i64::lte(tick, max_tick()), E_TICK_OUT_OF_BOUNDS);
        if (i64::is_neg(tick)) {
            get_sqrt_price_at_negative_tick(tick)
        } else {
            get_sqrt_price_at_positive_tick(tick)
        }
    }

    #[view]
    public fun get_tick_at_sqrt_price(sqrt_price: u128): i64::I64 {
        assert!(sqrt_price >= 4295048016 && sqrt_price <= 79226673515401279992447579055, E_SQRT_PRICE_OUT_OF_BOUNDS);
        let shift6 = as_u8(sqrt_price >= 18446744073709551616) << 6;
        let sqrt_price_shifted = sqrt_price >> shift6;
        let shift5 = as_u8(sqrt_price_shifted >= 4294967296) << 5;
        let sqrt_price_shifted2 = sqrt_price_shifted >> shift5;
        let shift4 = as_u8(sqrt_price_shifted2 >= 65536) << 4;
        let sqrt_price_shifted3 = sqrt_price_shifted2 >> shift4;
        let shift3 = as_u8(sqrt_price_shifted3 >= 256) << 3;
        let sqrt_price_shifted4 = sqrt_price_shifted3 >> shift3;
        let shift2 = as_u8(sqrt_price_shifted4 >= 16) << 2;
        let sqrt_price_shifted5 = sqrt_price_shifted4 >> shift2;
        let shift1 = as_u8(sqrt_price_shifted5 >= 4) << 1;
        let msb = 0 | shift6 | shift5 | shift4 | shift3 | shift2 | shift1 | as_u8(
            sqrt_price_shifted5 >> shift1 >= 2
        ) << 0;

        let log_2_x32 = i128::shl(i128::sub(i128::from((msb as u128)), i128::from(64)), 32);
        let normalized_price = if (msb >= 64) {
            sqrt_price >> msb - 63
        } else {
            sqrt_price << 63 - msb
        };

        let shift = 31;
        while (shift >= 18) {
            let squared = normalized_price * normalized_price >> 63;
            let bit = ((squared >> 64) as u8);
            log_2_x32 = i128::or(log_2_x32, i128::shl(i128::from((bit as u128)), shift));
            normalized_price = squared >> bit;
            shift = shift - 1;
        };
        let log_sqrt_10001 = i128::mul(log_2_x32, i128::from(59543866431366));
        let tick_low = i128::as_i64(i128::shr(i128::sub(log_sqrt_10001, i128::from(184467440737095516)), 64));
        let tick_high = i128::as_i64(i128::shr(i128::add(log_sqrt_10001, i128::from(15793534762490258745)), 64));
        if (i64::eq(tick_low, tick_high)) {
            return tick_low
        };
        if (get_sqrt_price_at_tick(tick_high) <= sqrt_price) {
            return tick_high
        };
        tick_low
    }

    public fun is_valid_index(index: i64::I64, tick_spacing: u64): bool {
        i64::gte(index, min_tick()) && i64::lte(index, max_tick()) && i64::mod(
            index,
            i64::from(tick_spacing)
        ) == i64::from(0)
    }

    #[view]
    public fun max_sqrt_price(): u128 {
        79226673515401279992447579055
    }

    #[view]
    public fun max_tick(): i64::I64 {
        i64::from(443636)
    }

    #[view]
    public fun min_sqrt_price(): u128 {
        4295048016
    }

    #[view]
    public fun min_tick(): i64::I64 {
        i64::neg_from(443636)
    }

    #[view]
    public fun tick_bound(): u64 {
        443636
    }

    // decompiled from Move bytecode v6
}

