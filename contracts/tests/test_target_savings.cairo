use contracts::contractss::target_savings::TargetSavings::{
    Event, GoalCreated, ITargetSavingsDispatcher, ITargetSavingsDispatcherTrait, GoalEdited,
    GoalDeleted, FundsDeposited,
};
use contracts::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_block_timestamp, cheat_caller_address, declare, spy_events,
};
use starknet::{ContractAddress, contract_address_const};

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}
// const OWNER: ContractAddress = 'OWNER'.try_into().unwrap();
// const USER: ContractAddress = 'USER'.try_into().unwrap();

// #[starknet::interface]
// trait ITargetSavings<T> {
//     // Goal management
//     fn create_goal(
//         ref self: T,
//         token_address: ContractAddress,
//         target_amount: u256,
//         deadline: u64,
//         name: felt252,
//     ) -> u64;

//     fn edit_goal(
//         ref self: T,
//         goal_id: u64,
//         new_target_amount: u256,
//         new_deadline: u64,
//         new_name: felt252,
//     );

//     fn delete_goal(ref self: T, goal_id: u64);

//     // Fund management
//     fn deposit(ref self: T, goal_id: u64, amount: u256);
//     fn withdraw(ref self: T, goal_id: u64, amount: u256);
//     fn withdraw_with_penalty(ref self: T, goal_id: u64, amount: u256);

//     // View functions
//     fn get_goal(self: @T, goal_id: u64) -> SavingsGoal;
//     fn get_user_goals(self: @T) -> Array<SavingsGoal>;
//     fn get_goal_progress(self: @T, goal_id: u64) -> (u256, u256);
//     fn is_goal_reached(self: @T, goal_id: u64) -> bool;
//     fn is_goal_deadline_passed(self: @T, goal_id: u64) -> bool;
// }

fn deploy() -> ITargetSavingsDispatcher {
    let mut calldata = array![];
    OWNER().serialize(ref calldata);

    let class = declare("TargetSavings").unwrap().contract_class();
    let (contract_address, _) = class.deploy(@calldata).unwrap();
    ITargetSavingsDispatcher { contract_address }
}

fn erc20() -> ContractAddress {
    let class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![OWNER().into(), OWNER().into(), 18];
    let (contract_address, _) = class.deploy(@calldata).unwrap();
    contract_address
}

fn default_goal(dispatcher: ITargetSavingsDispatcher) -> (u64, IERC20Dispatcher) {
    let token = erc20();
    let target_amount = 1000;
    let deadline = 10;
    let name = 'YOUR NAME';
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 0, CheatSpan::TargetCalls(1));
    let goal_id = dispatcher.create_goal(token, target_amount, deadline, name);

    (goal_id, IERC20Dispatcher { contract_address: token })
}

#[test]
fn test_target_savings_create_goal_success() {
    let dispatcher = deploy();
    let mut spy = spy_events();
    let (goal_id, token) = default_goal(dispatcher);
    let event = Event::GoalCreated(
        GoalCreated {
            user: USER(),
            goal_id,
            token: token.contract_address,
            target_amount: 1000,
            deadline: 10,
            name: 'YOUR NAME',
        },
    );
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);
}

#[test]
fn test_target_savings_edit_goal_sucess() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher);
    // NOTE: goal was created by USER
    let deadline = dispatcher.get_goal(goal_id);
    assert(deadline.deadline == 10, 'WRONG DEADLINE');

    let mut spy = spy_events();
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 10, CheatSpan::Indefinite);
    dispatcher.edit_goal(goal_id, 5000, 11, 'MY NAME');

    let event = Event::GoalEdited(
        GoalEdited {
            user: USER(), goal_id, new_target_amount: 5000, new_deadline: 11, new_name: 'MY NAME',
        },
    );
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);
}

#[test]
#[should_panic(expected: 'Not goal owner')]
fn test_target_savings_edit_goal_should_panic_on_non_owner() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher);
    let random_user = OWNER();

    cheat_caller_address(dispatcher.contract_address, random_user, CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 10, CheatSpan::Indefinite);
    dispatcher.edit_goal(goal_id, 1000, 11, 'MY NAME');
}

#[test]
fn test_target_savings_delete_goal_success() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher);
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    let mut spy = spy_events();
    dispatcher.delete_goal(goal_id);

    let event = Event::GoalDeleted(GoalDeleted { user: USER(), goal_id });
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);
}

#[test]
fn test_target_savings_deposit_success() {
    let dispatcher = deploy();
    let (goal_id, token) = default_goal(dispatcher);
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let deposit = 7500;
    let amount = 3000;
    let amount2 = deposit - amount;
    token.transfer(USER(), deposit);
    assert(token.balance_of(USER()) == deposit, 'INVALID AMOUNT');

    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    let mut spy = spy_events();
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, amount);
    assert(token.balance_of(USER()) == amount2, 'DEPOSIT FAILED');

    assert(dispatcher.get_goal(goal_id).current_amount == amount, 'DEPOSIT FAILED.');
    
    dispatcher.deposit(goal_id, amount2);
    
    let event1 = Event::FundsDeposited(FundsDeposited { user: USER(), goal_id, amount });
    let event2 = Event::FundsDeposited(FundsDeposited { user: USER(), goal_id, amount: amount2 });

    let events = array![
        (dispatcher.contract_address, event1), (dispatcher.contract_address, event2),
    ];
    spy.assert_emitted(@events);
    assert(dispatcher.get_goal(goal_id).current_amount == deposit, 'DEPOSIT FAILED..');
}

#[test]
fn test_target_savings_delete_goal_refund_success() {}
// pub struct SavingsGoal {
//     pub id: u64,
//     pub owner: ContractAddress,
//     pub token_address: ContractAddress,
//     pub target_amount: u256,
//     pub current_amount: u256,
//     pub deadline: u64,
//     pub name: felt252,
//     pub active: bool,
// }

//     fn edit_goal(
//         ref self: T,
//         goal_id: u64,
//         new_target_amount: u256,
//         new_deadline: u64,
//         new_name: felt252,
//     );


