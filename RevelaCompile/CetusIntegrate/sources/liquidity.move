module dexlyn_integrate::liquidity {

    use std::option;
    use std::string::String;

    use dexlyn_clmm::clmm_router::remove_liquidity;
    use dexlyn_clmm::clmm_router::{add_liquidity, create_pool};
    use dexlyn_clmm::factory;
    use dexlyn_integrate::rewarder::{
        collect_rewarder_for_one,
        collect_rewarder_for_three,
        collect_rewarder_for_two
    };

    fun get_clmmpool_address<CoinA, CoinB>(
        tick_spacing: u64
    ): option::Option<address> {
        factory::get_pool<CoinA, CoinB>(tick_spacing)
    }

    public entry fun create_and_add_liquidity<CoinA, CoinB>(
        account: &signer,
        tick_spacing: u64,
        init_sqrt_price: u128,
        uri: String,
        delta_liquidity: u128,
        max_amount_a: u64,
        max_amount_b: u64,
        tick_lower: u64,
        tick_upper: u64,
    ) {
        create_pool<CoinA, CoinB>(
            account,
            tick_spacing,
            init_sqrt_price,
            uri
        );
        // Verify if the pool is already created
        let clmm_pool_addr_opt = get_clmmpool_address<CoinA, CoinB>(tick_spacing);
        let pool_address = option::extract(&mut clmm_pool_addr_opt);

        // Add liquidity
        add_liquidity<CoinA, CoinB>(
            account,
            pool_address,
            delta_liquidity,
            max_amount_a,
            max_amount_b,
            tick_lower,
            tick_upper,
            true,
            0
        );
    }

    public entry fun remove_all_liquidity<CoinA, CoinB, CoinC>(
        owner: &signer,
        pool_address: address,
        delta_liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        pos_index: u64,
        is_close: bool,
    ) {
        remove_liquidity<CoinA, CoinB>(
            owner,
            pool_address,
            delta_liquidity,
            min_amount_a,
            min_amount_b,
            pos_index,
            is_close
        );
        collect_rewarder_for_one<CoinA, CoinB, CoinC>(owner, pool_address, pos_index);
    }

    public entry fun remove_all_liquidity_for_two<CoinA, CoinB, CoinC, CoinD>(
        owner: &signer,
        pool_address: address,
        delta_liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        pos_index: u64,
        is_close: bool,
    ) {
        remove_liquidity<CoinA, CoinB>(
            owner,
            pool_address,
            delta_liquidity,
            min_amount_a,
            min_amount_b,
            pos_index,
            is_close
        );
        collect_rewarder_for_two<CoinA, CoinB, CoinC, CoinD>(owner, pool_address, pos_index);
    }

    public entry fun remove_all_liquidity_for_three<CoinA, CoinB, CoinC, CoinD, CoinE>(
        owner: &signer,
        pool_address: address,
        delta_liquidity: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        pos_index: u64,
        is_close: bool,
    ) {
        remove_liquidity<CoinA, CoinB>(
            owner,
            pool_address,
            delta_liquidity,
            min_amount_a,
            min_amount_b,
            pos_index,
            is_close
        );
        collect_rewarder_for_three<CoinA, CoinB, CoinC, CoinD, CoinE>(owner, pool_address, pos_index);
    }
}