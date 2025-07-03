module dexlyn_clmm::acl {

    use std::error;
    use aptos_std::table::{Self, Table};

    struct ACL has store {
        permissions: Table<address, u128>,
    }

    public fun new(): ACL {
        ACL { permissions: table::new<address, u128>() }
    }

    public fun add_role(acl: &mut ACL, member: address, role: u8) {
        assert!(role < 128, error::invalid_argument(0));
        if (table::contains<address, u128>(&acl.permissions, member)) {
            let member_permissions = table::borrow_mut<address, u128>(&mut acl.permissions, member);
            *member_permissions = *member_permissions | 1 << role;
        } else {
            table::add<address, u128>(&mut acl.permissions, member, 1 << role);
        };
    }

    public fun has_role(acl: &ACL, member: address, role: u8): bool {
        assert!(role < 128, error::invalid_argument(0));
        table::contains<address, u128>(&acl.permissions, member) && *table::borrow<address, u128>(
            &acl.permissions,
            member
        ) & 1 << role > 0
    }

    public fun remove_role(acl: &mut ACL, member: address, role: u8) {
        assert!(role < 128, error::invalid_argument(0));
        if (table::contains<address, u128>(&acl.permissions, member)) {
            let member_permissions = table::borrow_mut<address, u128>(&mut acl.permissions, member);
            *member_permissions = *member_permissions - (1 << role);
        };
    }

    public fun set_roles(acl: &mut ACL, member: address, permissions: u128) {
        if (table::contains<address, u128>(&acl.permissions, member)) {
            *table::borrow_mut<address, u128>(&mut acl.permissions, member) = permissions;
        } else {
            table::add<address, u128>(&mut acl.permissions, member, permissions);
        };
    }

    // decompiled from Move bytecode v6
}

