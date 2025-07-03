module dexlyn_clmm::partner {

    use std::signer;
    use std::string::{Self, String};
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};

    use supra_framework::account;
    use supra_framework::coin;
    use supra_framework::event;
    use supra_framework::timestamp;

    use dexlyn_clmm::config;

    /// the partner already exists
    const E_PARTNER_ALREADY_EXISTS: u64 = 1;

    /// the partner does not exist
    const E_PARTNER_NOT_FOUND: u64 = 2;

    /// the partner is not authorized
    const E_NOT_AUTHORIZED: u64 = 3;

    /// the time is invalid
    const E_INVALID_TIME: u64 = 4;

    /// the fee rate is too high
    const E_FEE_RATE_TOO_HIGH: u64 = 5;

    /// the name is empty
    const E_EMPTY_NAME: u64 = 6;


    const PARTNER_FEE_RATE_DENOMINATOR: u64 = 10000;

    #[event]
    struct AcceptReceiverEvent has drop, store {
        name: String,
        receiver: address,
        timestamp: u64,
    }

    #[event]
    struct ClaimRefFeeEvent has drop, store {
        name: String,
        receiver: address,
        coin_type: TypeInfo,
        amount: u64,
        timestamp: u64,
    }

    #[event]
    struct CreateEvent has drop, store {
        partner_address: address,
        fee_rate: u64,
        name: String,
        receiver: address,
        start_time: u64,
        end_time: u64,
        timestamp: u64,
    }

    struct Partner has store {
        metadata: PartnerMetadata,
        signer_capability: account::SignerCapability,
    }

    struct PartnerMetadata has copy, drop, store {
        partner_address: address,
        receiver: address,
        pending_receiver: address,
        fee_rate: u64,
        start_time: u64,
        end_time: u64,
    }

    struct Partners has key {
        data: Table<String, Partner>,
    }

    #[event]
    struct ReceiveRefFeeEvent has drop, store {
        name: String,
        amount: u64,
        coin_type: TypeInfo,
        timestamp: u64,
    }

    #[event]
    struct TransferReceiverEvent has drop, store {
        name: String,
        old_receiver: address,
        new_receiver: address,
        timestamp: u64,
    }

    #[event]
    struct UpdateFeeRateEvent has drop, store {
        name: String,
        old_fee_rate: u64,
        new_fee_rate: u64,
        timestamp: u64,
    }

    #[event]
    struct UpdateTimeEvent has drop, store {
        name: String,
        start_time: u64,
        end_time: u64,
        timestamp: u64,
    }

    public fun accept_receiver(receiver: &signer, name: String) acquires Partners {
        let receiver_addr = signer::address_of(receiver);
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, name), E_PARTNER_NOT_FOUND);
        let partner = table::borrow_mut<String, Partner>(&mut partners.data, name);
        assert!(receiver_addr == partner.metadata.pending_receiver, E_NOT_AUTHORIZED);
        partner.metadata.receiver = receiver_addr;
        partner.metadata.pending_receiver = @0x0;
        let accept_receiver_event = AcceptReceiverEvent {
            name: name,
            receiver: receiver_addr,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<AcceptReceiverEvent>(accept_receiver_event);
    }

    public fun claim_ref_fee<CoinType>(receiver: &signer, name: String) acquires Partners {
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, name), E_PARTNER_NOT_FOUND);
        let partner = table::borrow<String, Partner>(&partners.data, name);
        assert!(signer::address_of(receiver) == partner.metadata.receiver, E_NOT_AUTHORIZED);
        let amount = coin::balance<CoinType>(partner.metadata.partner_address);
        let signer_cap = account::create_signer_with_capability(&partner.signer_capability);
        if (!coin::is_account_registered<CoinType>(signer::address_of(receiver))) {
            coin::register<CoinType>(receiver);
        };
        coin::deposit<CoinType>(partner.metadata.receiver, coin::withdraw<CoinType>(&signer_cap, amount));
        let claim_ref_fee_event = ClaimRefFeeEvent {
            name: name,
            receiver: partner.metadata.receiver,
            coin_type: type_info::type_of<CoinType>(),
            amount: amount,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<ClaimRefFeeEvent>(claim_ref_fee_event);
    }

    public fun create_partner(
        admin: &signer,
        name: String,
        fee_rate: u64,
        receiver_address: address,
        start_time: u64,
        end_time: u64
    ) acquires Partners {
        assert!(end_time > start_time, E_INVALID_TIME);
        assert!(end_time > timestamp::now_seconds(), E_INVALID_TIME);
        assert!(fee_rate < PARTNER_FEE_RATE_DENOMINATOR, E_FEE_RATE_TOO_HIGH);
        assert!(!string::is_empty(&name), E_EMPTY_NAME);
        config::assert_protocol_authority(admin);
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(!table::contains<String, Partner>(&partners.data, name), E_PARTNER_ALREADY_EXISTS);
        let (resource_signer, signer_capability) = account::create_resource_account(admin, *string::bytes(&name));
        let partner_signer = resource_signer;
        let partner_address = signer::address_of(&partner_signer);
        let partner_metadata = PartnerMetadata {
            partner_address: partner_address,
            receiver: receiver_address,
            pending_receiver: @0x0,
            fee_rate: fee_rate,
            start_time: start_time,
            end_time: end_time,
        };
        let partner = Partner {
            metadata: partner_metadata,
            signer_capability: signer_capability,
        };
        table::add<String, Partner>(&mut partners.data, name, partner);
        let create_event = CreateEvent {
            partner_address: partner_address,
            fee_rate: fee_rate,
            name: name,
            receiver: receiver_address,
            start_time: start_time,
            end_time: end_time,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<CreateEvent>(create_event);
    }

    #[view]
    public fun get_ref_fee_rate(receiver: String): u64 acquires Partners {
        let partners_data = &borrow_global<Partners>(@dexlyn_clmm).data;
        if (!table::contains<String, Partner>(partners_data, receiver)) {
            return 0
        };
        let partner = table::borrow<String, Partner>(partners_data, receiver);
        let time = timestamp::now_seconds();
        if (partner.metadata.start_time > time || partner.metadata.end_time <= time) {
            return 0
        };
        partner.metadata.fee_rate
    }

    public fun initialize(receiver: &signer) {
        config::assert_initialize_authority(receiver);
        let partners = Partners {
            data: table::new<String, Partner>(),
        };
        move_to<Partners>(receiver, partners);
    }

    #[view]
    public fun partner_fee_rate_denominator(): u64 {
        PARTNER_FEE_RATE_DENOMINATOR
    }

    public fun receive_ref_fee<CoinType>(receiver: String, ref_fee_coin: coin::Coin<CoinType>) acquires Partners {
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, receiver), E_PARTNER_NOT_FOUND);
        let partner = table::borrow<String, Partner>(&partners.data, receiver);
        if (!coin::is_account_registered<CoinType>(partner.metadata.partner_address)) {
            let signer_cap = account::create_signer_with_capability(&partner.signer_capability);
            coin::register<CoinType>(&signer_cap);
        };
        let coin_value = coin::value<CoinType>(&ref_fee_coin);
        coin::deposit<CoinType>(partner.metadata.partner_address, ref_fee_coin);
        let receive_reff_event = ReceiveRefFeeEvent {
            name: receiver,
            amount: coin_value,
            coin_type: type_info::type_of<CoinType>(),
            timestamp: timestamp::now_seconds(),
        };
        event::emit<ReceiveRefFeeEvent>(receive_reff_event);
    }

    public fun transfer_receiver(receiver: &signer, name: String, new_receiver: address) acquires Partners {
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, name), E_PARTNER_NOT_FOUND);
        let partner = table::borrow_mut<String, Partner>(&mut partners.data, name);
        assert!(signer::address_of(receiver) == partner.metadata.receiver, E_NOT_AUTHORIZED);
        partner.metadata.pending_receiver = new_receiver;
        let transfer_receiver_event = TransferReceiverEvent {
            name: name,
            old_receiver: partner.metadata.receiver,
            new_receiver: new_receiver,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<TransferReceiverEvent>(transfer_receiver_event);
    }

    public fun update_fee_rate(receiver: &signer, name: String, new_fee_rate: u64) acquires Partners {
        assert!(new_fee_rate < PARTNER_FEE_RATE_DENOMINATOR, E_FEE_RATE_TOO_HIGH);
        config::assert_protocol_authority(receiver);
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, name), E_PARTNER_NOT_FOUND);
        let partner = table::borrow_mut<String, Partner>(&mut partners.data, name);
        partner.metadata.fee_rate = new_fee_rate;
        let update_feerate_event = UpdateFeeRateEvent {
            name: name,
            old_fee_rate: partner.metadata.fee_rate,
            new_fee_rate: new_fee_rate,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateFeeRateEvent>(update_feerate_event);
    }

    public fun update_time(receiver: &signer, name: String, start_time: u64, end_time: u64) acquires Partners {
        assert!(end_time > start_time, E_INVALID_TIME);
        assert!(end_time > timestamp::now_seconds(), E_INVALID_TIME);
        config::assert_protocol_authority(receiver);
        let partners = borrow_global_mut<Partners>(@dexlyn_clmm);
        assert!(table::contains<String, Partner>(&partners.data, name), E_PARTNER_NOT_FOUND);
        let partner = table::borrow_mut<String, Partner>(&mut partners.data, name);
        partner.metadata.start_time = start_time;
        partner.metadata.end_time = end_time;
        let update_time_event = UpdateTimeEvent {
            name: name,
            start_time: start_time,
            end_time: end_time,
            timestamp: timestamp::now_seconds(),
        };
        event::emit<UpdateTimeEvent>(update_time_event);
    }

    // decompiled from Move bytecode v6
}

