module dexlyn_clmm::fee_tier {

    use std::timestamp;
    use aptos_std::simple_map::{Self, SimpleMap};

    use supra_framework::event;

    use dexlyn_clmm::config;

    /// the fee tier already exists
    const E_FEE_TIER_EXISTS: u64 = 1;

    /// the fee tier does not exist
    const E_FEE_TIER_NOT_FOUND: u64 = 2;

    /// the fee rate is too high
    const E_FEE_RATE_TOO_HIGH: u64 = 3;

    const MAX_FEE_RATE: u64 = 200000;

    #[event]
    struct AddEvent has drop, store {
        tick_spacing: u64,
        fee_rate: u64,
        timestamp: u64,
    }

    #[event]
    struct DeleteEvent has drop, store {
        tick_spacing: u64,
        timestamp: u64,
    }

    struct FeeTier has copy, drop, store {
        tick_spacing: u64,
        fee_rate: u64,
    }

    struct FeeTiers has key {
        fee_tiers: SimpleMap<u64, FeeTier>,
    }

    #[event]
    struct UpdateEvent has drop, store {
        tick_spacing: u64,
        old_fee_rate: u64,
        new_fee_rate: u64,
        timestamp: u64,
    }

    public fun add_fee_tier(account: &signer, tick_spacing: u64, fee_rate: u64) acquires FeeTiers {
        assert!(fee_rate <= MAX_FEE_RATE, E_FEE_RATE_TOO_HIGH);
        config::assert_protocol_authority(account);
        let fees = borrow_global_mut<FeeTiers>(@dexlyn_clmm);
        assert!(!simple_map::contains_key<u64, FeeTier>(&fees.fee_tiers, &tick_spacing), E_FEE_TIER_EXISTS);
        let new_fee_tier = FeeTier {
            tick_spacing: tick_spacing,
            fee_rate: fee_rate,
        };
        simple_map::add<u64, FeeTier>(&mut fees.fee_tiers, tick_spacing, new_fee_tier);
        let add_event = AddEvent {
            tick_spacing: tick_spacing,
            fee_rate: fee_rate,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<AddEvent>(add_event);
    }

    public fun delete_fee_tier(account: &signer, tick_spacing: u64) acquires FeeTiers {
        config::assert_protocol_authority(account);
        let fees = borrow_global_mut<FeeTiers>(@dexlyn_clmm);
        assert!(simple_map::contains_key<u64, FeeTier>(&fees.fee_tiers, &tick_spacing), E_FEE_TIER_NOT_FOUND);
        simple_map::remove<u64, FeeTier>(&mut fees.fee_tiers, &tick_spacing);
        let delete_event = DeleteEvent { tick_spacing: tick_spacing, timestamp: timestamp::now_seconds() };
        event::emit<DeleteEvent>(delete_event);
    }

    #[view]
    public fun get_fee_rate(tick_spacing: u64): u64 acquires FeeTiers {
        let fees = &borrow_global<FeeTiers>(@dexlyn_clmm).fee_tiers;
        assert!(simple_map::contains_key<u64, FeeTier>(fees, &tick_spacing), E_FEE_TIER_NOT_FOUND);
        simple_map::borrow<u64, FeeTier>(fees, &tick_spacing).fee_rate
    }

    public fun initialize(account: &signer) {
        config::assert_initialize_authority(account);
        let fees = FeeTiers {
            fee_tiers: simple_map::create<u64, FeeTier>(),
        };
        move_to<FeeTiers>(account, fees);
    }

    #[view]
    public fun max_fee_rate(): u64 {
        MAX_FEE_RATE
    }

    public fun update_fee_tier(account: &signer, tick_spacing: u64, fee_rate: u64) acquires FeeTiers {
        assert!(fee_rate <= MAX_FEE_RATE, E_FEE_RATE_TOO_HIGH);
        config::assert_protocol_authority(account);
        let fees = borrow_global_mut<FeeTiers>(@dexlyn_clmm);
        assert!(simple_map::contains_key<u64, FeeTier>(&fees.fee_tiers, &tick_spacing), E_FEE_TIER_NOT_FOUND);
        let fee_tier = simple_map::borrow_mut<u64, FeeTier>(&mut fees.fee_tiers, &tick_spacing);
        fee_tier.fee_rate = fee_rate;
        let update_event = UpdateEvent {
            tick_spacing: tick_spacing,
            old_fee_rate: fee_tier.fee_rate,
            new_fee_rate: fee_rate,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateEvent>(update_event);
    }

    // decompiled from Move bytecode v6
}

