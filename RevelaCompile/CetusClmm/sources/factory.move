module dexlyn_clmm::factory {

    use std::bcs;
    use std::option;
    use std::signer;
    use std::string::{Self, String};
    use std::timestamp;
    use aptos_std::comparator;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::type_info::{Self, TypeInfo};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::event;

    use dexlyn_clmm::config;
    use dexlyn_clmm::fee_tier;
    use dexlyn_clmm::partner;
    use dexlyn_clmm::pool;
    use dexlyn_clmm::tick_math;
    use dexlyn_clmm::utils;

    const CETUS_POOL_OWNER: vector<u8> = b"CetusPoolOwner";

    /// the pool already exists
    const E_POOL_ALREADY_EXISTS: u64 = 1;

    /// the initial sqrt price is invalid
    const E_INVALID_SQRT_PRICE: u64 = 2;

    #[event]
    struct CreatePoolEvent has drop, store {
        creator: address,
        pool_address: address,
        position_collection_name: String,
        coin_type_a: String,
        coin_type_b: String,
        tick_spacing: u64,
        timestamp: u64,
        init_sqrt_price: u128
    }

    struct PoolId has copy, drop, store {
        coin_type_a: TypeInfo,
        coin_type_b: TypeInfo,
        tick_spacing: u64,
    }

    struct PoolOwner has key {
        signer_capability: SignerCapability,
    }

    struct Pools has key {
        data: SimpleMap<PoolId, address>,
        index: u64,
    }

    public fun create_pool<CoinA, CoinB>(
        account: &signer,
        tick_spacing: u64,
        init_sqrt_price: u128,
        uri: String
    ): address acquires PoolOwner, Pools {
        config::assert_pool_create_authority(account);
        let uri_string = if (string::length(&uri) == 0 || !config::allow_set_position_nft_uri(account)) {
            string::utf8(
                b""
            )
        } else {
            uri
        };
        assert!(
            init_sqrt_price >= tick_math::min_sqrt_price() && init_sqrt_price <= tick_math::max_sqrt_price(),
            E_INVALID_SQRT_PRICE
        );
        let pool_id = new_pool_id<CoinA, CoinB>(tick_spacing);
        let pool_owner_resource_signer = account::create_signer_with_capability(
            &borrow_global<PoolOwner>(@dexlyn_clmm).signer_capability
        );
        let pool_seed = new_pool_seed<CoinA, CoinB>(tick_spacing);
        let (resource_signer, signer_cap) = account::create_resource_account(
            &pool_owner_resource_signer,
            bcs::to_bytes<PoolId>(&pool_seed)
        );
        let resource_address = signer::address_of(&resource_signer);
        let pool_mut = borrow_global_mut<Pools>(@dexlyn_clmm);
        pool_mut.index = pool_mut.index + 1;
        assert!(!simple_map::contains_key<PoolId, address>(&pool_mut.data, &pool_id), E_POOL_ALREADY_EXISTS);
        simple_map::add<PoolId, address>(&mut pool_mut.data, pool_id, resource_address);
        let create_pool_event = CreatePoolEvent {
            creator: signer::address_of(account),
            pool_address: resource_address,
            position_collection_name: pool::new<CoinA, CoinB>(
                &resource_signer,
                tick_spacing,
                init_sqrt_price,
                pool_mut.index,
                uri_string,
                signer_cap
            ),
            coin_type_a: type_info::type_name<CoinA>(),
            coin_type_b: type_info::type_name<CoinB>(),
            tick_spacing: tick_spacing,
            timestamp: timestamp::now_seconds(),
            init_sqrt_price: init_sqrt_price
        };
        event::emit<CreatePoolEvent>(create_pool_event);
        resource_address
    }

    #[view]
    public fun get_pool<CoinA, CoinB>(tick_spacing: u64): option::Option<address> acquires Pools {
        let pools = borrow_global<Pools>(@dexlyn_clmm);
        let pool_id = new_pool_id<CoinA, CoinB>(tick_spacing);
        if (simple_map::contains_key<PoolId, address>(&pools.data, &pool_id)) {
            return option::some<address>(*simple_map::borrow<PoolId, address>(&pools.data, &pool_id))
        };
        option::none<address>()
    }

    fun init_module(deployer: &signer) {
        let pool = Pools {
            data: simple_map::create<PoolId, address>(),
            index: 0,
        };
        move_to<Pools>(deployer, pool);
        let (_, signer_cap) = account::create_resource_account(deployer, CETUS_POOL_OWNER);
        let pool_owner = PoolOwner { signer_capability: signer_cap };
        move_to<PoolOwner>(deployer, pool_owner);
        config::initialize(deployer);
        fee_tier::initialize(deployer);
        partner::initialize(deployer);
    }

    fun new_pool_id<CoinA, CoinB>(tick_spacing: u64): PoolId {
        PoolId {
            coin_type_a: type_info::type_of<CoinA>(),
            coin_type_b: type_info::type_of<CoinB>(),
            tick_spacing: tick_spacing,
        }
    }

    fun new_pool_seed<CoinA, CoinB>(tick_spacing: u64): PoolId {
        let result_compare = utils::compare_coin<CoinA, CoinB>();
        if (comparator::is_smaller_than(&result_compare)) {
            PoolId {
                coin_type_a: type_info::type_of<CoinA>(), coin_type_b: type_info::type_of<CoinB>(
                ), tick_spacing: tick_spacing
            }
        } else {
            PoolId {
                coin_type_a: type_info::type_of<CoinB>(), coin_type_b: type_info::type_of<CoinA>(
                ), tick_spacing: tick_spacing
            }
        }
    }

    #[test_only(admin= @dexlyn_clmm)]
    public fun init_factory_module(admin: &signer) {
        init_module(admin);
    }

    // decompiled from Move bytecode v6
}

