use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SavingsGoal {
    pub id: u64,
    pub owner: ContractAddress,
    pub token_address: ContractAddress,
    pub target_amount: u256,
    pub current_amount: u256,
    pub deadline: u64,
    pub name: felt252,
    pub active: bool,
}
