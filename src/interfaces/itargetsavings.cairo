use piggystark::structs::target_savings_structs::SavingsGoal;
use starknet::ContractAddress;

#[starknet::interface]
pub trait ITargetSavings<T> {
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