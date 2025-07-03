module dexlyn_clmm::position_nft {
    use std::option;
    use std::string::{Self, String,utf8};
    use aptos_std::bcs;
    use aptos_framework::object::{Self, Object};
    use std::debug::print;

    use aptos_framework::coin;

    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use std::signer;

    const KEY_INDEX: vector<u8> = b"index";
    const KEY_TOKEN_BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct PositionNFT has key {
        mutator_ref: token::MutatorRef,
        burn_ref: token::BurnRef,
        property_mutator_ref: property_map::MutatorRef,
    }

    public fun create_collection<CoinA, CoinB>(
        creator: &signer,
        tick: u64,
        description: String,
        uri: String
    ): String {
        let name = collection_name<CoinA, CoinB>(tick);
        let max_supply = 1;
        let royalty = option::none();

        // Create collection with Digital Asset Standard
        collection::create_unlimited_collection(
            creator,
            description,
            name,
            royalty, // No royalty
            uri
        );

        name
    }

    public fun is_position_nft_owner(
        owner: address,
        collection_name: String,
        pool_index: u64,
        position_index: u64
    ): bool {
        // print(&utf8(b"Print token name and adddress in is_position_nft_owner function"));
        let token_name = position_name(pool_index, position_index);
        // print(&token_name);
        let token_address = token::create_token_address(
            &owner,
            &collection_name,
            &token_name
        );
        print(&utf8(b"Token address in is_position_nft_owner function"));
        print(&token_address);
        exists<PositionNFT>(token_address)
    }

    public fun burn_by_collection_and_index(
        creator: &signer,
        owner: address,
        collection_name: String,
        pool_index: u64,
        position_index: u64
    ) acquires PositionNFT {
        let token_name = position_name(pool_index, position_index);
        let token_address = token::create_token_address(
            &owner,
            &collection_name,
            &token_name
        );
        let token_obj = object::address_to_object<PositionNFT>(token_address);
        burn(creator, token_obj);
    }

    public fun burn(
        creator: &signer,
        token: Object<PositionNFT>
    ) acquires PositionNFT {
        let position_nft = move_from<PositionNFT>(object::object_address(&token));
        let PositionNFT { mutator_ref: _, burn_ref, property_mutator_ref } = position_nft;

        property_map::remove(&property_mutator_ref, &string::utf8(KEY_INDEX));
        property_map::remove(&property_mutator_ref, &string::utf8(KEY_TOKEN_BURNABLE_BY_CREATOR));
        token::burn(burn_ref);
    }

    #[view]
    public fun collection_name<CoinA, CoinB>(tick: u64): String {
        let name = string::utf8(b"Dexlyn Position | ");
        string::append(&mut name, coin::symbol<CoinA>());
        string::append_utf8(&mut name, b"-");
        string::append(&mut name, coin::symbol<CoinB>());
        string::append_utf8(&mut name, b"_tick(");
        string::append(&mut name, dexlyn_clmm::utils::str(tick));
        string::append_utf8(&mut name, b")");
        name
    }

    public fun mint(
        creator: &signer,
        receiver: &signer,
        index: u64,
        position_index: u64,
        uri: String,
        collection_name: String
    ) {
        let token_name = position_name(index, position_index);
        let token_description = string::utf8(b"Dexlyn CLMM Position NFT");
        let royalty = option::none();

        // print(&utf8(b"Print Token address and name in Mint function"));
        let token_address = token::create_token_address(
            &signer::address_of(receiver),
            &collection_name,
            &token_name
        );
        print(&token_address);
        // print(&token_name);
        // print(&collection_name);

        // Create token with Digital Asset Standard
        let constructor_ref = token::create_named_token(
            creator,
            collection_name,
            token_description,
            token_name,
            royalty,
            uri,
        );

        property_map::init(&constructor_ref, property_map::prepare_input(vector[], vector[], vector[]));
        
        let object_signer = object::generate_signer(&constructor_ref);
        let mutator_ref = token::generate_mutator_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);

        property_map::add_typed(
            &property_mutator_ref,
            string::utf8(KEY_INDEX),
            bcs::to_bytes(&position_index)
        );
        property_map::add_typed(
            &property_mutator_ref,
            string::utf8(KEY_TOKEN_BURNABLE_BY_CREATOR),
            bcs::to_bytes(&true)
        );

        print(&utf8(b"Object Signer in mint"));
        print(&object_signer);
        // Store PositionNFT resource at the object address (no transfer needed)
        move_to(&object_signer, PositionNFT {
            mutator_ref,
            burn_ref,
            property_mutator_ref,
        });

        let token_address = token::create_token_address(
            &signer::address_of(receiver),
            &collection_name,
            &token_name
        );
        print(&exists<PositionNFT>(token_address));
    }

    public fun mutate_collection_uri(_creator: &signer, _collection_name: String, _new_uri: String) {}

    #[view]
    public fun position_name(index: u64, position_index: u64): String {
        let name = string::utf8(b"Dexlyn LP | Pool");
        string::append(&mut name, dexlyn_clmm::utils::str(index));
        string::append_utf8(&mut name, b"-");
        string::append(&mut name, dexlyn_clmm::utils::str(position_index));
        name
    }
}