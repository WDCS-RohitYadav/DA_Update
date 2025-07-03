// module supra_clmm::position_nft {

//     use std::bcs::to_bytes;
//     use std::option;
//     use std::string;
//     use std::string::String;
//     use supra_framework::object;
//     use supra_framework::object::ExtendRef;
//     use aptos_token_objects::collection;
//     use aptos_token_objects::token;
//     use aptos_token_objects::token::{BurnRef, Token};

//     const COLLECTION_NAME: vector<u8> = b"SUPRA_POSITION_COLLECTION";

//     #[resource_group_member(group = supra_framework::object::ObjectGroup)]
//     struct CollectionData has key {
//         extende_ref: ExtendRef
//     }

//     #[resource_group_member(group = supra_framework::object::ObjectGroup)]
//     struct PositionToken has key {
//         burn_ref: BurnRef
//     }

//     public fun init_module(sender: &signer) {
//         let constructor_ref = collection::create_unlimited_collection(
//             sender,
//             string::utf8(b"Supra Position NFT Collection"),
//             string::utf8(COLLECTION_NAME),
//             option::none(),
//             string::utf8(b"https://example.com/position_collection.jpg"),
//         );

//         let extend_ref = object::generate_extend_ref(&constructor_ref);
//         let collection_signer = object::generate_signer(&constructor_ref);

//         move_to(&collection_signer, CollectionData {
//             extende_ref: extend_ref
//         });
//     }

//     public entry fun mint_position_nft(
//         sender: &signer,
//         token_uri: String,
//         token_name: String,
//         token_description: String,
//     ) {
//         let constructor_ref = token::create_named_token(
//             sender,
//             string::utf8(COLLECTION_NAME),
//             string::utf8(to_bytes(&token_description)),
//             string::utf8(to_bytes(&token_name)),
//             option::none(),
//             string::utf8(to_bytes(&token_uri)),
//         );

//         let token_signer = &object::generate_signer(&constructor_ref);
//         let burn_ref = token::generate_burn_ref(&constructor_ref);

//         move_to(token_signer, PositionToken {
//             burn_ref: burn_ref
//         });
//     }

//     public entry fun transfer_position_nft(
//         sender: &signer,
//         recipient: address,
//         token_id: address,
//     ) {
//         let token = object::address_to_object<Token>(token_id);
//         object::transfer(sender, token, recipient);
//     }

//     public entry fun burn_position_nft(
//         sender: &signer,
//         token_id: address,
//     ) acquires PositionToken {
//         let token_data = move_from<PositionToken>(token_id);
//         let PositionToken { burn_ref } = token_data;
//         token::burn(burn_ref)
//     }
// }