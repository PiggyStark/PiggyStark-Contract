#[starknet::contract]
pub mod PiggyStark {
    use piggystark::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use piggystark::interfaces::ipiggystark::IPiggyStark;
    use piggystark::structs::piggystructs::{Asset, SavingsTarget};
    use piggystark::errors::piggystark_errors::Errors;
    use core::num::traits::Zero;
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        user_deposits: Map<ContractAddress, Map<ContractAddress, Option<Asset>>>, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
        balance: Map<ContractAddress, u256>, // Track total balance per token
        targets_count: u64, // Total created targets, used to assign new IDs
        targets: Map<u64, SavingsTarget> // Map SavingsTarget to its target ID
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
        AssetCreated: AssetCreated,
        Withdrawal: Withdrawal,
        TargetCreated: TargetCreated,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct SuccessfulDeposit {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AssetCreated {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub token_name: felt252,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawal {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetCreated {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub goal: u256,
        pub deadline: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn create_asset(ref self: ContractState, token_address: ContractAddress, amount: u256, token_name: felt252) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller: ContractAddress = get_caller_address();
            let contract: ContractAddress = get_contract_address();

            let existing_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(existing_asset_ref.is_none(), errors.ASSET_ALREADY_EXISTS);

            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, contract, amount);

            // Create new asset
            let new_asset = Asset { token_name, token_address, balance: amount };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));
            self.deposited_tokens.push(token_address);

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance + amount);

            self.emit(AssetCreated { caller, token: token_address, token_name, amount });
        }

        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Transfer tokens from user to contract
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, contract, amount);

            // Update user deposit balance
            let prev_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(prev_asset_ref.is_none(), errors.ASSET_DOES_NOT_EXIST);

            let prev_asset = prev_asset_ref.unwrap();
            let new_balance = prev_asset.balance + amount;
            assert(new_balance > prev_asset.balance, errors.AMOUNT_OVERFLOWS_BALANCE);

            let new_asset = Asset { token_name: prev_asset.token_name, token_address, balance: new_balance };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(new_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance + amount);

            self.emit(SuccessfulDeposit { caller, token: token_address, amount });
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller = get_caller_address();
            let contract = get_contract_address();

            // Check if user has the asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.ASSET_DOES_NOT_EXIST);

            let asset = asset_ref.unwrap();
            assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);

            // Update user's asset balance
            let new_balance = asset.balance - amount;
            let updated_asset = Asset { token_name: asset.token_name, token_address, balance: new_balance };
            self.user_deposits.entry(caller).entry(token_address).write(Option::Some(updated_asset));

            // Update total balance
            let current_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_balance - amount);

            // Transfer tokens back to user
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer(caller, amount);

            self.emit(Withdrawal { caller, token: token_address, amount });
        }

        fn create_target(
            ref self: ContractState, token_address: ContractAddress, goal: u256, deadline: u64,
        ) -> u64 {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(goal > 0, errors.ZERO_GOAL_AMOUNT);

            let current_time = get_block_timestamp();
            assert(deadline > current_time, errors.INVALID_DEADLINE);

            let target_id = self.targets_count.read() + 1;
            self.targets_count.write(target_id);

            let new_target = SavingsTarget { id: target_id, token_address, goal, deadline };
            self.targets.entry(target_id).write(new_target);

            self
                .emit(
                    TargetCreated {
                        caller: get_caller_address(), token: token_address, goal, deadline,
                    },
                );

            target_id
        }

        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            let caller = get_caller_address();
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();

            match asset_ref {
                Option::Some(asset) => asset.balance,
                Option::None => 0
            }
        }
    }
}
