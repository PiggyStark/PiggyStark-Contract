pub mod Errors {
    #[derive(Drop)]
    pub struct Errors {
        pub ZERO_TOKEN_ADDRESS: felt252,
        pub ZERO_TOKEN_AMOUNT: felt252,
        pub ASSET_ALREADY_EXISTS: felt252,
        pub USER_DOES_NOT_POSSESS_TOKEN: felt252,
        pub AMOUNT_OVERFLOWS_BALANCE: felt252,
        pub ASSET_DOES_NOT_EXIST: felt252,
        pub ZERO_ADDRESS_CALLER: felt252,
        pub CALLED_WITH_ZERO_ADDRESS: felt252,
        pub NO_TOKENS_AVAILABLE: felt252,
        pub SHOULD_HAVE_NO_TOKENS: felt252,
        pub INCORRECT_BALANCE: felt252,
        pub ZERO_GOAL_AMOUNT: felt252,
        pub INVALID_DEADLINE: felt252,
    }

    pub fn new() -> Errors {
        Errors {
            ZERO_TOKEN_ADDRESS: 'Token address cannot be zero',
            ZERO_TOKEN_AMOUNT: 'Token amount cannot be zero',
            ASSET_ALREADY_EXISTS: 'Asset already exists',
            USER_DOES_NOT_POSSESS_TOKEN: 'User does not possess token',
            AMOUNT_OVERFLOWS_BALANCE: 'Amount overflows balance',
            ASSET_DOES_NOT_EXIST: 'Asset does not exist',
            ZERO_ADDRESS_CALLER: 'Zero Address Caller',
            CALLED_WITH_ZERO_ADDRESS: 'Called with the zero address',
            NO_TOKENS_AVAILABLE: 'no tokens available',
            SHOULD_HAVE_NO_TOKENS: 'should have no tokens',
            INCORRECT_BALANCE: 'incorrect balance',
            ZERO_GOAL_AMOUNT: 'Goal amount cannot be zero',
            INVALID_DEADLINE: 'Invalid deadline',
        }
    }
}
