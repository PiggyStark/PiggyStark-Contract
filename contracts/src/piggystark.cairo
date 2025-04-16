#[starknet::contract]
pub mod PiggyStark {
    use contracts::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::interfaces::ipiggystark::IPiggyStark;
    use contracts::structs::piggystructs::Asset;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait, StorageMapReadAccess, StorageMapWriteAccess
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {

       owner: ContractAddress,
       // Mapping from user address to the token address they deposited
       user_deposits: Map::<ContractAddress, Vec<(ContractAddress, u256)>>, // Map user address to a Vec of token address, token amount pair
    //    locked_funds: Map::<ContractAddress, Vec<(ContractAddress, u256)>>,
        // deposited_token: Map::<ContractAddress, ContractAddress>,
        // Mapping from (user address, token address) to deposit amount
        deposit_values: Map::<(ContractAddress, ContractAddress), u256>,
        balance: Map<ContractAddress, u256>,
        // deposit_values: Map::<(ContractAddress, ContractAddress), u256>,

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SuccessfulDeposit {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            assert(token_address.is_non_zero(), 'Token address cannot be zero');
            assert(amount > 0, 'Token amount cannot be zero');

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Transfer tokens from user to contract
            IERC20Dispatcher { contract_address: token_address }
                .transfer_from(caller, contract, amount);

            // Update user deposit balance
            let prev_deposit = self.user_deposits.entry(caller).entry(token_address).read();
            self.user_deposits.entry(caller).entry(token_address).write(prev_deposit + amount);

            self.emit(SuccessfulDeposit { caller, token: token_address, amount });
        }
        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {}


        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let caller = get_caller_address();
            let mut assets = ArrayTrait::new();
            let deposits = self.user_deposits.entry(caller);
            let len = deposits.len();
            let mut i: u64 = 0;
            while i != len {
                let (token_address, amount) = deposits.at(i).read();
                assets
                    .append(
                        Asset {
                            token_name: "PIGGY STARK",
                            token_address: token_address,
                            balance: amount,
                        },
                    );
                i = i + 1;
            }

            assets
        }


        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            self.balance.read(token_address)
        }
    }
}
