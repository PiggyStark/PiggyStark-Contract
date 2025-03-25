#[starknet::contract]
pub mod PiggyStark {
    use contracts::{
        interfaces::ipiggystark::IPiggyStark, 
        structs::piggystructs::Asset
    };
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };

    // Added balance_of to sTorage struct
    #[storage]
    struct Storage {
        balance_of: Map<ContractAddress, u256>
    }

    fn constructor(){}

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {}
        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {}
        fn get_user_assets(self: @ContractState) -> Array<Asset> {}
        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            self.balance_of.read(token_address);
        }
    }
}