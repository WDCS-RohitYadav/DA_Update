module dexlyn_clmm::utils {

    use std::string::{Self, String};
    use std::vector;
    use aptos_std::comparator::{Self, Result};
    use aptos_std::type_info::{type_of, TypeInfo};

    #[view]
    public fun compare_coin<CoinA, CoinB>(): Result {
        let coin_a_type_info = type_of<CoinA>();
        let coin_b_type_info = type_of<CoinB>();
        comparator::compare<TypeInfo>(&coin_a_type_info, &coin_b_type_info)
    }

    #[view]
    public fun str(num: u64): String {
        if (num == 0) {
            return string::utf8(b"0")
        };
        let num_ascii_holder = vector::empty<u8>();
        while (num > 0) {
            let reminder = ((num % 10) as u8);
            num = num / 10;
            vector::push_back<u8>(&mut num_ascii_holder, reminder + 48);
        };
        vector::reverse<u8>(&mut num_ascii_holder);
        string::utf8(num_ascii_holder)
    }

    // decompiled from Move bytecode v6
}

