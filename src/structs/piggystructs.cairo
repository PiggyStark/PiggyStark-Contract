use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Asset {
    pub token_name: felt252,
    pub token_address: ContractAddress,
    pub balance: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Target {
    pub user: ContractAddress,
    pub goal: u256,
    pub deadline: u64,
    pub current_amount: u256,
}
