pub mod Errors {
    #[derive(Drop)]
    pub struct Errors {
        pub ZERO_TOKEN_ADDRESS: felt252,
        pub ZERO_TOKEN_AMOUNT: felt252,
        pub ASSET_ALREADY_EXISTS: felt252,
        pub USER_DOES_NOT_POSSESS_TOKEN: felt252,
        pub AMOUNT_OVERFLOWS_BALANCE: felt252,
        pub ASSET_DOES_NOT_EXIST: felt252,
        pub CALLED_WITH_ZERO_ADDRESS: felt252,
        pub NO_TOKENS_AVAILABLE: felt252,
        pub SHOULD_HAVE_NO_TOKENS: felt252,
        pub INCORRECT_BALANCE: felt252,
        pub ZERO_USER_ADDRESS: felt252,
        pub ZERO_LOCK_ID: felt252,
        pub ZERO_LOCK_DURATION: felt252,
        pub LOCK_DURATION_NOT_EXPIRED: felt252,
        pub TOKEN_ADDRESS_MISMATCH: felt252,
        pub INACTIVE_LOCK: felt252,
        pub NOT_LOCK_OWNER: felt252,
        pub ZERO_GOAL_AMOUNT: felt252,
        pub INVALID_DEADLINE: felt252,
        pub TOKEN_DOES_NOT_MATCH_TARGET: felt252,
        pub TARGET_DEADLINE_PASSED: felt252,
        pub USER_DOES_NOT_OWN_TARGET: felt252,
    }

    pub fn new() -> Errors {
        Errors {
            ZERO_TOKEN_ADDRESS: 'Token address cannot be zero',
            ZERO_TOKEN_AMOUNT: 'Token amount cannot be zero',
            ASSET_ALREADY_EXISTS: 'Asset already exists',
            USER_DOES_NOT_POSSESS_TOKEN: 'User does not possess token',
            AMOUNT_OVERFLOWS_BALANCE: 'Amount overflows balance',
            ASSET_DOES_NOT_EXIST: 'Asset does not exist',
            CALLED_WITH_ZERO_ADDRESS: 'Called with the zero address',
            NO_TOKENS_AVAILABLE: 'no tokens available',
            SHOULD_HAVE_NO_TOKENS: 'should have no tokens',
            INCORRECT_BALANCE: 'incorrect balance',
            ZERO_USER_ADDRESS: 'user address cannot be zero',
            ZERO_LOCK_ID: 'lock id cannot be zero',
            ZERO_LOCK_DURATION: 'Lock duration cannot be zero',
            LOCK_DURATION_NOT_EXPIRED: 'Lock duration not expired',
            TOKEN_ADDRESS_MISMATCH: 'Token address mismatch',
            INACTIVE_LOCK: 'Inactive lock',
            NOT_LOCK_OWNER: 'Not lock owner',


            ZERO_GOAL_AMOUNT: 'Goal amount cannot be zero',
            INVALID_DEADLINE: 'Invalid deadline',
            TOKEN_DOES_NOT_MATCH_TARGET: 'Token does not match target',
            TARGET_DEADLINE_PASSED: 'Target deadline passed',
            USER_DOES_NOT_OWN_TARGET: 'User does not own this target',
        }
    }
}
