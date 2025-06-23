#[starknet::contract]
pub mod PiggyStark {
    use core::num::traits::Zero;
    use piggystark::errors::piggystark_errors::Errors;
    use piggystark::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use piggystark::interfaces::ipiggystark::IPiggyStark;
    use piggystark::structs::piggystructs::{Asset, SavingsTarget};
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        user_deposits: Map<
            ContractAddress, Map<ContractAddress, Option<Asset>>,
        >, // Map user address to a Map of token address, (option) token amount key-value
        deposited_tokens: Vec<ContractAddress>,
        balance: Map<ContractAddress, u256>, // Track total balance per token
        targets_count: u64, // Total created targets, used to assign new IDs
        targets: Map<u64, SavingsTarget>, // Map SavingsTarget to its target ID
        user_targets: Map<ContractAddress, Vec<u64>>, // Map user address to their target IDs
        target_balances: Map<u64, u256> // Track balance for each target
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        SuccessfulDeposit: SuccessfulDeposit,
        AssetCreated: AssetCreated,
        Withdrawal: Withdrawal,
        TargetCreated: TargetCreated,
        TargetContributed: TargetContributed,
        TargetCompleted: TargetCompleted,
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
        pub target_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetContributed {
        pub caller: ContractAddress,
        pub target_id: u64,
        pub amount: u256,
        pub remaining: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TargetCompleted {
        pub caller: ContractAddress,
        pub target_id: u64,
        pub total_saved: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl PiggyStarkImpl of IPiggyStark<ContractState> {
        fn create_asset(
            ref self: ContractState,
            token_address: ContractAddress,
            amount: u256,
            token_name: felt252,
        ) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller: ContractAddress = get_caller_address();
            let _contract: ContractAddress = get_contract_address();

            let existing_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(existing_asset_ref.is_none(), errors.ASSET_ALREADY_EXISTS);

            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, _contract, amount);

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
            assert(caller.is_non_zero(), errors.CALLED_WITH_ZERO_ADDRESS);
            let _contract = get_contract_address();

            // Check if user has the asset
            let prev_asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(prev_asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);

            // Transfer tokens from user to contract
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, _contract, amount);

            let prev_asset = prev_asset_ref.unwrap();
            let new_balance = prev_asset.balance + amount;
            assert(new_balance > prev_asset.balance, errors.AMOUNT_OVERFLOWS_BALANCE);

            let new_asset = Asset {
                token_name: prev_asset.token_name, token_address, balance: new_balance,
            };
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
            assert(caller.is_non_zero(), errors.CALLED_WITH_ZERO_ADDRESS);
            let _contract = get_contract_address();

            // Check if user has the asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);

            let asset = asset_ref.unwrap();
            assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);

            // Update user's asset balance
            let new_balance = asset.balance - amount;
            let updated_asset = Asset {
                token_name: asset.token_name, token_address, balance: new_balance,
            };
            self
                .user_deposits
                .entry(caller)
                .entry(token_address)
                .write(Option::Some(updated_asset));

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

            let caller = get_caller_address();
            let target_id = self.targets_count.read() + 1;
            self.targets_count.write(target_id);

            let new_target = SavingsTarget { id: target_id, token_address, goal, deadline };
            self.targets.entry(target_id).write(new_target);
            self.target_balances.entry(target_id).write(0);

            // Add target to user's list of targets
            self.user_targets.entry(caller).push(target_id);

            self.emit(TargetCreated { caller, token: token_address, goal, deadline, target_id });

            target_id
        }

        fn contribute_to_target(
            ref self: ContractState, token_address: ContractAddress, target_id: u64, amount: u256,
        ) {
            let errors = Errors::new();
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);
            assert(amount > 0, errors.ZERO_TOKEN_AMOUNT);

            let caller = get_caller_address();
            assert(caller.is_non_zero(), errors.CALLED_WITH_ZERO_ADDRESS);

            // Check target exists
            let target = self.targets.entry(target_id).read();

            // Check token matches target
            assert(target.token_address == token_address, errors.TOKEN_DOES_NOT_MATCH_TARGET);

            // Check deadline not passed
            let current_time = get_block_timestamp();
            assert(target.deadline > current_time, errors.TARGET_DEADLINE_PASSED);

            // Transfer tokens from user to contract
            let _contract = get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            erc20_dispatcher.transfer_from(caller, _contract, amount);

            // Update target balance
            let prev_balance = self.target_balances.entry(target_id).read();
            let new_balance = prev_balance + amount;
            assert(new_balance > prev_balance, errors.AMOUNT_OVERFLOWS_BALANCE);
            self.target_balances.entry(target_id).write(new_balance);

            // Update user's asset balance if user has the asset
            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            if asset_ref.is_some() {
                let asset = asset_ref.unwrap();
                assert(asset.balance >= amount, errors.AMOUNT_OVERFLOWS_BALANCE);
                let updated_asset = Asset {
                    token_name: asset.token_name, token_address, balance: asset.balance - amount,
                };
                self
                    .user_deposits
                    .entry(caller)
                    .entry(token_address)
                    .write(Option::Some(updated_asset));
            }

            // Update total token balance
            let current_token_balance = self.balance.entry(token_address).read();
            self.balance.entry(token_address).write(current_token_balance + amount);

            // Emit event
            let remaining = if new_balance >= target.goal {
                0
            } else {
                target.goal - new_balance
            };
            self.emit(TargetContributed { caller, target_id, amount, remaining });

            // If target completed, emit event
            if new_balance >= target.goal {
                self.emit(TargetCompleted { caller, target_id, total_saved: new_balance });
            }
        }


        fn get_user_targets(self: @ContractState, user: ContractAddress) -> Array<u64> {
            let mut target_ids = array![];
            let user_targets = self.user_targets.entry(user);

            let len = user_targets.len();
            for i in 0..len {
                target_ids.append(user_targets.at(i).read());
            }
            target_ids
        }

        fn get_deposited_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut tokens = array![];
            let len = self.deposited_tokens.len();
            for i in 0..len {
                tokens.append(self.deposited_tokens.at(i).read());
            }
            tokens
        }

        fn get_token_balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            let errors = Errors::new();
            let caller = get_caller_address();
            assert(caller.is_non_zero(), errors.CALLED_WITH_ZERO_ADDRESS);

            let asset_ref = self.user_deposits.entry(caller).entry(token_address).read();
            assert(asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);

            asset_ref.unwrap().balance
        }

        fn get_user_assets(self: @ContractState) -> Array<Asset> {
            let caller = get_caller_address();
            let mut assets = ArrayTrait::new();
            for i in 0..self.deposited_tokens.len() {
                let token_address = self.deposited_tokens.at(i).read();
                let current_user_possesses = self
                    .user_deposits
                    .entry(caller)
                    .entry(token_address)
                    .read();
                assert(current_user_possesses.is_some(), 'Not owned by user');
                let user_asset = current_user_possesses.unwrap();
                assets.append(user_asset);
            }
            assets
        }


        fn get_balance(
            self: @ContractState, user: ContractAddress, token_address: ContractAddress,
        ) -> u256 {
            let errors = Errors::new();
            assert(user.is_non_zero(), errors.CALLED_WITH_ZERO_ADDRESS);
            assert(token_address.is_non_zero(), errors.ZERO_TOKEN_ADDRESS);

            let asset_ref = self.user_deposits.entry(user).entry(token_address).read();
            assert(asset_ref.is_some(), errors.USER_DOES_NOT_POSSESS_TOKEN);

            asset_ref.unwrap().balance
        }
    }
}
