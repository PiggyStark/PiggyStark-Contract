use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Asset {
    token_name: ByteArray,
    token_address: ContractAddress,
    balance: u256
}