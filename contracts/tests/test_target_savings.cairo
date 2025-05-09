use contracts::contractss::target_savings::TargetSavings::{
    Event, GoalCreated, ITargetSavingsDispatcher, ITargetSavingsDispatcherTrait, GoalEdited,
    GoalDeleted, FundsDeposited, FundsWithdrawn, FundsWithdrawnWithPenalty,
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

//     fn withdraw_with_penalty(ref self: T, goal_id: u64, amount: u256);
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

fn default_goal(
    dispatcher: ITargetSavingsDispatcher, target_amount: u256,
) -> (u64, IERC20Dispatcher) {
    let token = erc20();
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
    let (goal_id, token) = default_goal(dispatcher, 1000);
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
fn test_target_savings_edit_goal_success() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher, 1000);
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
    let (goal_id, _) = default_goal(dispatcher, 1000);
    let random_user = OWNER();

    cheat_caller_address(dispatcher.contract_address, random_user, CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 10, CheatSpan::Indefinite);
    dispatcher.edit_goal(goal_id, 1000, 11, 'MY NAME');
}

#[test]
#[should_panic(expected: 'Inactive goal')]
fn test_target_savings_delete_goal_success() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher, 1000);
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    let mut spy = spy_events();
    dispatcher.delete_goal(goal_id);

    let event = Event::GoalDeleted(GoalDeleted { user: USER(), goal_id });
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);

    // when getting a deleted (non-existent) goal, it should panic with the message above
    dispatcher.get_goal(goal_id);
}

#[test]
fn test_target_savings_deposit_success() {
    let dispatcher = deploy();
    let deposit = 7500;
    let (goal_id, token) = default_goal(dispatcher, deposit);
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
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

    let (current, target) = dispatcher.get_goal_progress(goal_id);
    assert(current == amount && target == deposit, 'GET PROGRESS FAILED');

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
fn test_target_savings_delete_goal_refund_success() {
    let dispatcher = deploy();
    let (goal_id, token) = default_goal(dispatcher, 1000);
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let deposit = 7500;
    token.transfer(USER(), deposit);

    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, deposit);
    assert(token.balance_of(USER()) == 0, 'DEPOSIT FAILED');
    dispatcher.delete_goal(goal_id);
    assert(token.balance_of(USER()) == deposit, 'REFUND FAILED');
}
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

//     fn withdraw_with_penalty(ref self: T, goal_id: u64, amount: u256);
#[test]
fn test_target_savings_withdraw_success() {
    let dispatcher = deploy();
    let deposit = 1000;
    let (goal_id, token) = default_goal(dispatcher, deposit);
    // default goal amount is 1000
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    token.transfer(USER(), deposit);
    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, deposit);
    assert(token.balance_of(USER()) == 0, 'BALANCE SHOULD BE 0');
    assert(dispatcher.is_goal_reached(goal_id), 'GOAL NOT REACHED');
    assert(!dispatcher.is_goal_deadline_passed(goal_id), 'GOAL DEADLINE PASSED');

    let mut spy = spy_events();
    dispatcher.withdraw(goal_id, deposit);
    assert(token.balance_of(USER()) == deposit, 'INVALID BALANCE');

    let event = Event::FundsWithdrawn(FundsWithdrawn { user: USER(), goal_id, amount: deposit });
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);

    cheat_block_timestamp(dispatcher.contract_address, 11, CheatSpan::Indefinite);
    assert(dispatcher.is_goal_deadline_passed(goal_id), 'GOAL DEADLINE ERROR.');
}

#[test]
#[should_panic(expected: 'Goal not completed yet')]
fn test_target_savings_withdraw_should_panic_on_incomplete_goal() {
    let dispatcher = deploy();
    let (goal_id, token) = default_goal(dispatcher, 1000);
    // default goal amount is 1000
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let deposit = 400;
    token.transfer(USER(), deposit);
    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, deposit);
    assert(token.balance_of(USER()) == 0, 'BALANCE SHOULD BE 0');
    dispatcher.withdraw(goal_id, deposit);
}


#[test]
#[should_panic(expected: 'Insufficient funds')]
fn test_target_savings_withdraw_should_panic_on_insufficient_funds() {
    let dispatcher = deploy();
    let (goal_id, token) = default_goal(dispatcher, 1000);
    // default goal amount is 1000
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let deposit = 1000;
    token.transfer(USER(), deposit);
    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, deposit);
    dispatcher.withdraw(goal_id, deposit + 50);
}

#[test]
fn test_target_savings_get_user_goals_success() {
    let dispatcher = deploy();
    let (goal_id, _) = default_goal(dispatcher, 1000);
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::TargetCalls(1));
    let goals = dispatcher.get_user_goals();
    assert(goals.len() == 1, 'ERROR GETTING GOALS');

    let (goal_id2, _) = default_goal(dispatcher, 500);
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::TargetCalls(1));
    let goals = dispatcher.get_user_goals();
    assert(goals.len() == 2, 'INVALID GOALS LEN');

    // delete both goals
    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    dispatcher.delete_goal(goal_id);
    dispatcher.delete_goal(goal_id2);
    let goals = dispatcher.get_user_goals();
    assert(goals.len() == 0, 'GOALS LEN SHOULD BE 0');
}

#[test]
fn test_target_savings_withdraw_with_penalty_success() {
    let dispatcher = deploy();
    let deposit = 1000;
    let amount = 500;
    let initial_balance = deposit - amount;
    let (goal_id, token) = default_goal(dispatcher, deposit);
    // default goal amount is 1000
    cheat_caller_address(token.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    token.transfer(USER(), deposit);
    cheat_caller_address(token.contract_address, USER(), CheatSpan::TargetCalls(1));
    token.approve(dispatcher.contract_address, deposit);

    cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
    cheat_block_timestamp(dispatcher.contract_address, 1, CheatSpan::Indefinite);
    dispatcher.deposit(goal_id, amount);

    let mut spy = spy_events();
    dispatcher.withdraw_with_penalty(goal_id, amount);

    let penalty_amount = amount * 5 / 100;
    let withdrawn = amount - penalty_amount;
    println!("Balance: {}", token.balance_of(USER()));
    assert(token.balance_of(USER()) == initial_balance + withdrawn, 'PENALTY ERROR.'); // < deposit

    let event = Event::FundsWithdrawnWithPenalty(
        FundsWithdrawnWithPenalty { user: USER(), goal_id, amount, penalty_amount },
    );
    spy.assert_emitted(@array![(dispatcher.contract_address, event)]);
}
