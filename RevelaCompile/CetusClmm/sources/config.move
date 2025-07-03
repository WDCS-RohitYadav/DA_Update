module dexlyn_clmm::config {

    use std::signer;
    use std::timestamp;

    use supra_framework::event;

    use dexlyn_clmm::acl::{Self, ACL};

    // the signer is not authorized to perform the action
    const E_NOT_AUTHORIZED: u64 = 1;

    // the protocol fee rate is set too high
    const E_PROTOCOL_FEE_RATE_TOO_HIGH: u64 = 2;

    // the protocol is paused and an action is attempted
    const E_PROTOCOL_PAUSED: u64 = 3;

    // invalid role value is provided
    const E_INVALID_ROLE: u64 = 4;


    const DEFAULT_PROTOCOL_FEE_RATE: u64 = 2000;

    const MAX_PROTOCOL_FEE_RATE: u64 = 3000;


    #[event]
    struct AcceptAuthEvent has drop, store {
        old_auth: address,
        new_auth: address,
        timestamp: u64,
    }

    struct ClmmACL has key {
        acl: ACL,
    }

    struct GlobalConfig has key {
        protocol_authority: address,
        protocol_pending_authority: address,
        protocol_fee_claim_authority: address,
        pool_create_authority: address,
        protocol_fee_rate: u64,
        is_pause: bool,
    }

    #[event]
    struct TransferAuthEvent has drop, store {
        old_auth: address,
        new_auth: address,
        timestamp: u64,
    }

    #[event]
    struct UpdateClaimAuthEvent has drop, store {
        old_auth: address,
        new_auth: address,
        timestamp: u64,
    }

    #[event]
    struct UpdateFeeRateEvent has drop, store {
        old_fee_rate: u64,
        new_fee_rate: u64,
        timestamp: u64,
    }

    #[event]
    struct UpdatePoolCreateEvent has drop, store {
        old_auth: address,
        new_auth: address,
        timestamp: u64,
    }

    public fun add_role(admin: &signer, member: address, role: u8) acquires ClmmACL, GlobalConfig {
        assert!(role == 1 || role == 2, E_INVALID_ROLE);
        assert_protocol_authority(admin);
        acl::add_role(&mut borrow_global_mut<ClmmACL>(@dexlyn_clmm).acl, member, role);
    }

    public fun remove_role(admin: &signer, member: address, role: u8) acquires ClmmACL, GlobalConfig {
        assert!(role == 1 || role == 2, E_INVALID_ROLE);
        assert_protocol_authority(admin);
        acl::remove_role(&mut borrow_global_mut<ClmmACL>(@dexlyn_clmm).acl, member, role);
    }

    public fun accept_protocol_authority(admin: &signer) acquires GlobalConfig {
        let global_config = borrow_global_mut<GlobalConfig>(@dexlyn_clmm);
        assert!(global_config.protocol_pending_authority == signer::address_of(admin), E_NOT_AUTHORIZED);
        global_config.protocol_authority = signer::address_of(admin);
        global_config.protocol_pending_authority = @0x0;
        let accept_event = AcceptAuthEvent {
            old_auth: global_config.protocol_authority,
            new_auth: global_config.protocol_authority,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<AcceptAuthEvent>(accept_event);
    }

    public fun allow_set_position_nft_uri(admin: &signer): bool acquires ClmmACL {
        acl::has_role(&borrow_global<ClmmACL>(@dexlyn_clmm).acl, signer::address_of(admin), 1)
    }

    public fun assert_initialize_authority(admin: &signer) {
        assert!(signer::address_of(admin) == @dexlyn_clmm, E_NOT_AUTHORIZED);
    }

    public fun assert_pool_create_authority(admin: &signer) acquires GlobalConfig {
        let global_config = borrow_global<GlobalConfig>(@dexlyn_clmm);
        assert!(
            global_config.pool_create_authority == signer::address_of(
                admin
            ) || global_config.pool_create_authority == @0x0,
            E_NOT_AUTHORIZED
        );
    }

    public fun assert_protocol_authority(admin: &signer) acquires GlobalConfig {
        assert!(
            borrow_global<GlobalConfig>(@dexlyn_clmm).protocol_authority == signer::address_of(admin),
            E_NOT_AUTHORIZED
        );
    }

    public fun assert_protocol_fee_claim_authority(admin: &signer) acquires GlobalConfig {
        assert!(
            borrow_global<GlobalConfig>(@dexlyn_clmm).protocol_fee_claim_authority == signer::address_of(admin),
            E_NOT_AUTHORIZED
        );
    }

    public fun assert_protocol_status() acquires GlobalConfig {
        if (borrow_global<GlobalConfig>(@dexlyn_clmm).is_pause) {
            abort E_PROTOCOL_PAUSED
        };
    }

    public fun assert_reset_init_price_authority(admin: &signer) acquires ClmmACL {
        if (!acl::has_role(&borrow_global<ClmmACL>(@dexlyn_clmm).acl, signer::address_of(admin), 2)) {
            abort E_NOT_AUTHORIZED
        };
    }

    #[view]
    public fun get_protocol_fee_rate(): u64 acquires GlobalConfig {
        borrow_global<GlobalConfig>(@dexlyn_clmm).protocol_fee_rate
    }

    public fun init_clmm_acl(admin: &signer) {
        assert_initialize_authority(admin);
        let clmm_acl = ClmmACL { acl: acl::new() };
        move_to<ClmmACL>(admin, clmm_acl);
    }

    public fun initialize(admin: &signer) {
        assert_initialize_authority(admin);
        let global_config = GlobalConfig {
            protocol_authority: @dexlyn_clmm,
            protocol_pending_authority: @0x0,
            protocol_fee_claim_authority: @dexlyn_clmm,
            pool_create_authority: @0x0,
            protocol_fee_rate: DEFAULT_PROTOCOL_FEE_RATE,
            is_pause: false,
        };
        move_to<GlobalConfig>(admin, global_config);
    }

    public fun pause(admin: &signer) acquires GlobalConfig {
        assert_protocol_authority(admin);
        borrow_global_mut<GlobalConfig>(@dexlyn_clmm).is_pause = true;
    }

    public fun transfer_protocol_authority(admin: &signer, member: address) acquires GlobalConfig {
        assert_protocol_authority(admin);
        let global_config = borrow_global_mut<GlobalConfig>(@dexlyn_clmm);
        global_config.protocol_pending_authority = member;
        let transfer_event = TransferAuthEvent {
            old_auth: global_config.protocol_authority,
            new_auth: member,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<TransferAuthEvent>(transfer_event);
    }

    public fun unpause(admin: &signer) acquires GlobalConfig {
        assert_protocol_authority(admin);
        borrow_global_mut<GlobalConfig>(@dexlyn_clmm).is_pause = false;
    }

    public fun update_pool_create_authority(admin: &signer, member: address) acquires GlobalConfig {
        assert_protocol_authority(admin);
        let global_config = borrow_global_mut<GlobalConfig>(@dexlyn_clmm);
        global_config.pool_create_authority = member;
        let update_pool_event = UpdatePoolCreateEvent {
            old_auth: global_config.pool_create_authority,
            new_auth: global_config.pool_create_authority,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdatePoolCreateEvent>(update_pool_event);
    }

    public fun update_protocol_fee_claim_authority(admin: &signer, member: address) acquires GlobalConfig {
        assert_protocol_authority(admin);
        let global_config = borrow_global_mut<GlobalConfig>(@dexlyn_clmm);
        global_config.protocol_fee_claim_authority = member;
        let update_claim_event = UpdateClaimAuthEvent {
            old_auth: global_config.protocol_fee_claim_authority,
            new_auth: global_config.protocol_fee_claim_authority,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateClaimAuthEvent>(update_claim_event);
    }

    public fun update_protocol_fee_rate(admin: &signer, member: u64) acquires GlobalConfig {
        assert_protocol_authority(admin);
        assert!(member <= MAX_PROTOCOL_FEE_RATE, E_PROTOCOL_FEE_RATE_TOO_HIGH);
        let global_config = borrow_global_mut<GlobalConfig>(@dexlyn_clmm);
        global_config.protocol_fee_rate = member;
        let update_fee_event = UpdateFeeRateEvent {
            old_fee_rate: global_config.protocol_fee_rate,
            new_fee_rate: member,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateFeeRateEvent>(update_fee_event);
    }

    // decompiled from Move bytecode v6
}

