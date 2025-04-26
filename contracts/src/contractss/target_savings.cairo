#[starknet::contract]
pub mod TargetSavings {
    use core::array::ArrayTrait;
    use contracts::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::structs::target_savings_structs::SavingsGoal;
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,
        StorageMapReadAccess, StorageMapWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};

    const PENALTY_PERCENTAGE: u256 = 5; // 5% penalty for early withdrawal
    const PERCENTAGE_BASE: u256 = 100;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GoalCreated: GoalCreated,
        GoalEdited: GoalEdited,
        GoalDeleted: GoalDeleted,
        FundsDeposited: FundsDeposited,
        FundsWithdrawn: FundsWithdrawn,
        FundsWithdrawnWithPenalty: FundsWithdrawnWithPenalty,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GoalCreated {
        pub user: ContractAddress,
        pub goal_id: u64,
        pub token: ContractAddress,
        pub target_amount: u256,
        pub deadline: u64,
        pub name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GoalEdited {
        pub user: ContractAddress,
        pub goal_id: u64,
        pub new_target_amount: u256,
        pub new_deadline: u64,
        pub new_name: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GoalDeleted {
        pub user: ContractAddress,
        pub goal_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsDeposited {
        pub user: ContractAddress,
        pub goal_id: u64,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsWithdrawn {
        pub user: ContractAddress,
        pub goal_id: u64,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FundsWithdrawnWithPenalty {
        pub user: ContractAddress,
        pub goal_id: u64,
        pub amount: u256,
        pub penalty_amount: u256,
    }

    #[storage]
    struct Storage {
        owner: ContractAddress,
        goals_count: u64,
        // Maps user addresses to goals by ID
        user_goals: Map::<(ContractAddress, u64), bool>,
        // Maps goal IDs to SavingsGoal
        goals: Map::<u64, SavingsGoal>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.goals_count.write(0);
    }

    // Define the interface inline
    #[starknet::interface]
    trait ITargetSavings<T> {
        // Goal management
        fn create_goal(
            ref self: T,
            token_address: ContractAddress,
            target_amount: u256,
            deadline: u64,
            name: felt252,
        ) -> u64;

        fn edit_goal(
            ref self: T,
            goal_id: u64,
            new_target_amount: u256,
            new_deadline: u64,
            new_name: felt252,
        );

        fn delete_goal(ref self: T, goal_id: u64);

        // Fund management
        fn deposit(ref self: T, goal_id: u64, amount: u256);
        fn withdraw(ref self: T, goal_id: u64, amount: u256);
        fn withdraw_with_penalty(ref self: T, goal_id: u64, amount: u256);

        // View functions
        fn get_goal(self: @T, goal_id: u64) -> SavingsGoal;
        fn get_user_goals(self: @T) -> Array<SavingsGoal>;
        fn get_goal_progress(self: @T, goal_id: u64) -> (u256, u256);
        fn is_goal_reached(self: @T, goal_id: u64) -> bool;
        fn is_goal_deadline_passed(self: @T, goal_id: u64) -> bool;
    }

    #[abi(embed_v0)]
    impl TargetSavingsImpl of ITargetSavings<ContractState> {
        fn create_goal(
            ref self: ContractState,
            token_address: ContractAddress,
            target_amount: u256,
            deadline: u64,
            name: felt252,
        ) -> u64 {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');
            assert(token_address.is_non_zero(), 'Token address cannot be zero');
            assert(target_amount > 0, 'Target amount must be positive');

            let current_time = get_block_timestamp();
            assert(deadline > current_time, 'Future deadline required');

            // Create new goal
            let goal_id = self.goals_count.read() + 1;
            self.goals_count.write(goal_id);

            let new_goal = SavingsGoal {
                id: goal_id,
                owner: caller,
                token_address,
                target_amount,
                current_amount: 0,
                deadline,
                name,
                active: true,
            };

            // Store the goal
            self.goals.write(goal_id, new_goal);

            // Add goal ID to user's goals
            self.user_goals.write((caller, goal_id), true);

            // Emit event
            self
                .emit(
                    Event::GoalCreated(
                        GoalCreated {
                            user: caller,
                            goal_id,
                            token: token_address,
                            target_amount,
                            deadline,
                            name,
                        },
                    ),
                );

            goal_id
        }

        fn edit_goal(
            ref self: ContractState,
            goal_id: u64,
            new_target_amount: u256,
            new_deadline: u64,
            new_name: felt252,
        ) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');

            // Check if goal exists and belongs to caller
            let mut goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            assert(goal.owner == caller, 'Not goal owner');

            // Check validity of new values
            assert(new_target_amount > 0, 'Target amount must be positive');
            let current_time = get_block_timestamp();
            assert(new_deadline > current_time, 'Future deadline required');

            // If reducing the target amount, apply a penalty
            if new_target_amount < goal.target_amount {
                let original_target = goal.target_amount;
                let penalty_amount = (original_target - new_target_amount)
                    * PENALTY_PERCENTAGE
                    / PERCENTAGE_BASE;

                if penalty_amount > 0 && goal.current_amount > 0 {
                    // Apply penalty by reducing current_amount
                    if penalty_amount < goal.current_amount {
                        goal.current_amount = goal.current_amount - penalty_amount;
                    } else {
                        // If penalty is larger than current amount, set current amount to 0
                        goal.current_amount = 0;
                    }
                }
            }

            // Update goal with new values
            goal.target_amount = new_target_amount;
            goal.deadline = new_deadline;
            goal.name = new_name;
            self.goals.write(goal_id, goal);

            // Emit event
            self
                .emit(
                    Event::GoalEdited(
                        GoalEdited {
                            user: caller, goal_id, new_target_amount, new_deadline, new_name,
                        },
                    ),
                );
        }

        fn delete_goal(ref self: ContractState, goal_id: u64) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');

            // Check if goal exists and belongs to caller
            let mut goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            assert(goal.owner == caller, 'Not goal owner');

            // Withdraw all funds if any
            if goal.current_amount > 0 {
                let _contract_address = get_contract_address();
                IERC20Dispatcher { contract_address: goal.token_address }.transfer(caller, goal.current_amount);
            }

            // Deactivate goal
            goal.active = false;
            self.goals.write(goal_id, goal);

            // Remove from user's goals
            self.user_goals.write((caller, goal_id), false);

            // Emit event
            self.emit(Event::GoalDeleted(GoalDeleted { user: caller, goal_id }));
        }

        fn deposit(ref self: ContractState, goal_id: u64, amount: u256) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');
            assert(amount > 0, 'Amount must be positive');

            // Check if goal exists and belongs to caller
            let mut goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            assert(goal.owner == caller, 'Not goal owner');

            // Transfer tokens from user to contract
            let contract_address = get_contract_address();
            IERC20Dispatcher { contract_address: goal.token_address }
                .transfer_from(caller, contract_address, amount);

            // Update goal
            goal.current_amount = goal.current_amount + amount;
            self.goals.write(goal_id, goal);

            // Emit event
            self.emit(Event::FundsDeposited(FundsDeposited { user: caller, goal_id, amount }));
        }

        fn withdraw(ref self: ContractState, goal_id: u64, amount: u256) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');
            assert(amount > 0, 'Amount must be positive');

            // Check if goal exists and belongs to caller
            let mut goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            assert(goal.owner == caller, 'Not goal owner');

            // Check if goal is completed (target reached or deadline passed)
            let is_target_reached = goal.current_amount >= goal.target_amount;
            let is_deadline_passed = get_block_timestamp() >= goal.deadline;

            assert(is_target_reached || is_deadline_passed, 'Goal not completed yet');
            assert(amount <= goal.current_amount, 'Insufficient funds');

            // Transfer tokens from contract to user
            let _contract_address = get_contract_address();
            IERC20Dispatcher { contract_address: goal.token_address }.transfer(caller, amount);

            // Update goal
            goal.current_amount = goal.current_amount - amount;
            self.goals.write(goal_id, goal);

            // Emit event
            self.emit(Event::FundsWithdrawn(FundsWithdrawn { user: caller, goal_id, amount }));
        }

        fn withdraw_with_penalty(ref self: ContractState, goal_id: u64, amount: u256) {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');
            assert(amount > 0, 'Amount must be positive');

            // Check if goal exists and belongs to caller
            let mut goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            assert(goal.owner == caller, 'Not goal owner');
            assert(amount <= goal.current_amount, 'Insufficient funds');

            // Calculate penalty
            let penalty_amount = amount * PENALTY_PERCENTAGE / PERCENTAGE_BASE;
            let withdrawal_amount = amount - penalty_amount;

            // Transfer tokens from contract to user
            let _contract_address = get_contract_address();
            IERC20Dispatcher { contract_address: goal.token_address }.transfer(caller, withdrawal_amount);

            // Update goal
            goal.current_amount = goal.current_amount - amount;
            self.goals.write(goal_id, goal);

            // Emit event
            self
                .emit(
                    Event::FundsWithdrawnWithPenalty(
                        FundsWithdrawnWithPenalty { user: caller, goal_id, amount, penalty_amount },
                    ),
                );
        }

        fn get_goal(self: @ContractState, goal_id: u64) -> SavingsGoal {
            let goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            goal
        }

        fn get_user_goals(self: @ContractState) -> Array<SavingsGoal> {
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Zero Address Caller');

            let mut goals_array: Array<SavingsGoal> = ArrayTrait::new();
            let total_goals = self.goals_count.read();

            let mut i: u64 = 1;
            while i <= total_goals {
                let is_user_goal = self.user_goals.read((caller, i));
                if is_user_goal {
                    let goal = self.goals.read(i);
                    if goal.active {
                        goals_array.append(goal);
                    }
                }
                i += 1;
            };

            goals_array
        }

        fn get_goal_progress(self: @ContractState, goal_id: u64) -> (u256, u256) {
            let goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            (goal.current_amount, goal.target_amount)
        }

        fn is_goal_reached(self: @ContractState, goal_id: u64) -> bool {
            let goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            goal.current_amount >= goal.target_amount
        }

        fn is_goal_deadline_passed(self: @ContractState, goal_id: u64) -> bool {
            let goal = self.goals.read(goal_id);
            assert(goal.active, 'Inactive goal');
            get_block_timestamp() >= goal.deadline
        }
    }
}
