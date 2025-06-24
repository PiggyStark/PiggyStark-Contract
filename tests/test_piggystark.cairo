use core::traits::{Into, TryInto};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use piggystark::contracts::piggystark::PiggyStark::{
    AssetCreated, Event, Locked, NostraDeposit, NostraWithdrawal, SuccessfulDeposit,
    TargetCompleted, TargetContributed, TargetCreated, Unlocked, Withdrawal,
};
use piggystark::interfaces::inostra::{INostraDispatcher, INostraDispatcherTrait};
use piggystark::interfaces::ipiggystark::{IPiggyStarkDispatcher, IPiggyStarkDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, cheat_block_timestamp, declare,
    spy_events, start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_block_timestamp,
    stop_cheat_caller_address, test_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};


fn setup(owner: ContractAddress) -> (IPiggyStarkDispatcher, ContractAddress) {
    // Deploy mock ERC20
    let initial_supply: u256 = 100_000_000_000_000_000_000; // 100 tokens with 18 decimals
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 18];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    let contract_class = declare("PiggyStark").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address };
    (dispatcher, erc20_address)
}

// Utility functions
fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn NON_OWNER() -> ContractAddress {
    contract_address_const::<'NON_OWNER'>()
}

fn TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<'TOKEN_ADRESS'>()
}

fn ZERO() -> ContractAddress {
    contract_address_const::<0>()
}

fn ERRORS() -> piggystark::errors::piggystark_errors::Errors::Errors {
    piggystark::errors::piggystark_errors::Errors::new()
}

#[test]
fn test_successful_create_asset() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let token_name: felt252 = 'STK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, amount, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_zero_token_address_create_asset() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let token_name: felt252 = 'STK';
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(zero_address, amount, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_zero_amount_create_asset() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let token_name: felt252 = 'STK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 0, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Asset already exists')]
fn test_asset_existance_create_asset() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let token_name: felt252 = 'STK';

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, token_name);
    contract.create_asset(erc20_address, 100, token_name);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_deposit() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let create_amount: u256 = 300;
    let total_approval: u256 = amount + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_none_existing_token_deposit() {
    let owner = OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_zero_token_deposit() {
    let owner = OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STK');
    contract.deposit(erc20_address, 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_insufficient_deposit_allowance() {
    let owner = OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STK');
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_deposit() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let amount2: u256 = 200;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = 300;
    let total_deposits: u256 = large_amount + amount2 + amount2;
    let total_approval: u256 = total_deposits + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    contract.deposit(erc20_address, amount2);
    contract.deposit(erc20_address, amount2);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_withdraw() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = amount;
    let total_approval: u256 = large_amount + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    contract.withdraw(erc20_address, amount + 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = 300;
    let total_approval: u256 = large_amount + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    contract.withdraw(erc20_address, 345);
    contract.withdraw(erc20_address, 500_000);
    contract.withdraw(erc20_address, 400_000);
    contract.withdraw(erc20_address, 400);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount overflows balance')]
fn test_balance_overflow_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = 300;
    let total_approval: u256 = large_amount + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    contract.withdraw(erc20_address, large_amount); // Withdraw all the deposited amount
    contract.withdraw(erc20_address, 500_000); // Try to withdraw more than available balance
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_withdraw_from_non_existing_user_token() {
    let owner = OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_withdraw_from_Zero_caller_address() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.withdraw(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_token_balance() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let create_amount: u256 = 300;
    let total_approval: u256 = amount + create_amount;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, total_approval);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, amount);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);

    let expected_balance = amount + create_amount;
    assert(token_balance == expected_balance, ERRORS().INCORRECT_BALANCE);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_get_token_balance_for_none_exist_user_token() {
    let owner = OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_get_token_balance_from_Zero_caller_address() {
    let owner = OWNER();
    let amount: u256 = 1000;
    let zero_address = ZERO();

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, zero_address);
    contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_user_assets() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STK');
    let user_assets = contract.get_user_assets();
    stop_cheat_caller_address(contract.contract_address);
    assert(user_assets.len() > 0, ERRORS().NO_TOKENS_AVAILABLE);
}

#[test]
fn test_get_user_assets_no_token() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    let user_assets = contract.get_user_assets();
    stop_cheat_caller_address(contract.contract_address);
    assert(user_assets.len() == 0, ERRORS().SHOULD_HAVE_NO_TOKENS);
}

#[test]
fn test_create_target_success() {
    let owner = OWNER();
    let user = NON_OWNER();

    let class = declare("PiggyStark").unwrap().contract_class();
    let (addr, _) = class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address: addr };

    let token = TOKEN_ADDRESS();
    let goal = 100_u256;
    let deadline = get_block_timestamp() + 10;

    // Create first target
    start_cheat_caller_address(addr, user);
    let mut spy = spy_events();
    let id1 = dispatcher.create_target(token, goal, deadline);
    stop_cheat_caller_address(addr);

    // Verify returned ID
    assert(id1 == 1, 'first target ID should be 1');

    // Verify event emitted
    let expected1 = Event::TargetCreated(
        TargetCreated { caller: user, token, goal, deadline, target_id: 1 },
    );
    spy.assert_emitted(@array![(addr, expected1)]);

    // Create second target
    start_cheat_caller_address(addr, user);
    let id2 = dispatcher.create_target(token, goal, deadline + 10);
    stop_cheat_caller_address(addr);

    // Verify second ID
    assert(id2 == 2, 'second target ID should be 2');

    // Verify event emitted
    let expected2 = Event::TargetCreated(
        TargetCreated { caller: user, token, goal, deadline: deadline + 10, target_id: 2 },
    );
    spy.assert_emitted(@array![(addr, expected2)]);
}

#[test]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_create_target_reverts_on_zero_token() {
    let owner = OWNER();
    let user = NON_OWNER();

    let class = declare("PiggyStark").unwrap().contract_class();
    let (addr, _) = class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address: addr };

    let token = ZERO();
    let goal = 100_u256;
    let deadline = get_block_timestamp() + 10;

    // Attempt to create new target with zero token address
    start_cheat_caller_address(addr, user);
    dispatcher.create_target(token, goal, deadline);
    stop_cheat_caller_address(addr);
}

#[test]
#[should_panic(expected: 'Goal amount cannot be zero')]
fn test_create_target_reverts_on_zero_goal() {
    let owner = OWNER();
    let user = NON_OWNER();

    let class = declare("PiggyStark").unwrap().contract_class();
    let (addr, _) = class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address: addr };

    let token = TOKEN_ADDRESS();
    let goal = 0_u256;
    let deadline = get_block_timestamp() + 10;

    // Attempt to create new target with zero goal amount
    start_cheat_caller_address(addr, user);
    dispatcher.create_target(token, goal, deadline);
    stop_cheat_caller_address(addr);
}

#[test]
#[should_panic(expected: 'Invalid deadline')]
fn test_create_target_reverts_on_past_deadline() {
    let owner = OWNER();
    let user = NON_OWNER();

    let class = declare("PiggyStark").unwrap().contract_class();
    let (addr, _) = class.deploy(@array![owner.into()]).unwrap();
    let dispatcher = IPiggyStarkDispatcher { contract_address: addr };

    let token = TOKEN_ADDRESS();
    let goal = 100_u256;
    let deadline = get_block_timestamp(); // not in the future

    // Attempt to create new target with non-future deadline
    start_cheat_caller_address(addr, user);
    dispatcher.create_target(token, goal, deadline);
    stop_cheat_caller_address(addr);
}

#[test]
fn test_contribute_to_target_success() {
    let owner = OWNER();
    let user = NON_OWNER();

    // Deploy contracts and setup
    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, 40_000_u256);
    stop_cheat_caller_address(erc20_address);

    // User approves contract to spend tokens
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, 40_000_u256);
    stop_cheat_caller_address(erc20_address);
    // Approve tokens for user (NON_OWNER)
    let amount: u256 = 500;
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, amount);
    stop_cheat_caller_address(erc20_address);

    // Create a target as user
    let goal = 400_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Contribute to the target
    start_cheat_caller_address(contract.contract_address, user);
    let mut spy = spy_events();
    contract.contribute_to_target(erc20_address, target_id, 200_u256);
    // Check TargetContributed event
    let expected = Event::TargetContributed(
        TargetContributed { caller: user, target_id, amount: 200_u256, remaining: 200_u256 },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected)]);
    stop_cheat_caller_address(contract.contract_address);

    // Contribute again to complete the target
    start_cheat_caller_address(contract.contract_address, user);
    let mut spy2 = spy_events();
    contract.contribute_to_target(erc20_address, target_id, 200_u256);
    // Check TargetContributed and TargetCompleted events
    let expected2 = Event::TargetContributed(
        TargetContributed { caller: user, target_id, amount: 200_u256, remaining: 0_u256 },
    );
    let expected3 = Event::TargetCompleted(
        TargetCompleted { caller: user, target_id, total_saved: 400_u256 },
    );
    spy2
        .assert_emitted(
            @array![(contract.contract_address, expected2), (contract.contract_address, expected3)],
        );
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
#[should_panic(expected: 'Token address cannot be zero')]
fn test_contribute_to_target_zero_token_address() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute with zero token address
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(ZERO(), target_id, 10_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token amount cannot be zero')]
fn test_contribute_to_target_zero_amount() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute zero amount
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 0_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_contribute_to_target_zero_caller_address() {
    let owner = OWNER();
    let user = ZERO();
    let (contract, erc20_address) = setup(owner);

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    let real_user = NON_OWNER();
    start_cheat_caller_address(contract.contract_address, real_user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute as zero address
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 10_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Token does not match target')]
fn test_contribute_to_target_token_does_not_match() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);

    // Deploy a second ERC20 token
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 18];
    let (erc20_address2, _) = erc20_class.deploy(@calldata).unwrap();

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute with a different token address
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address2, target_id, 10_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_contribute_to_target_insufficient_allowance() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);

    // Give user tokens but do not approve contract
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, 100_u256);
    stop_cheat_caller_address(erc20_address);

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute without approval
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 10_u256);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount overflows balance')]
fn test_contribute_to_target_user_asset_balance_too_low() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);

    // Give user tokens and approve
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, 100_u256);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, 100_u256);
    stop_cheat_caller_address(erc20_address);

    // User creates asset with small balance
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, 10_u256, 'STK');
    stop_cheat_caller_address(contract.contract_address);

    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // Try to contribute more than asset balance
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 20_u256);
    stop_cheat_caller_address(contract.contract_address);
}


#[test]
fn test_get_balance_success() {
    let owner = OWNER();
    let user = NON_OWNER();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // Give user tokens and approve
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, amount);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, amount);
    stop_cheat_caller_address(erc20_address);

    // User creates asset
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, 300, 'STK');
    contract.deposit(erc20_address, 500);
    stop_cheat_caller_address(contract.contract_address);

    // Test get_balance from any caller (owner in this case)
    start_cheat_caller_address(contract.contract_address, owner);
    let balance = contract.get_balance(user, erc20_address);
    stop_cheat_caller_address(contract.contract_address);

    assert(balance == 800, 'Balance should be 800'); // 300 + 500
}


#[test]
fn test_get_balance_multiple_users() {
    let owner = OWNER();
    let user1 = NON_OWNER();
    let user2 = contract_address_const::<'USER2'>();
    let amount: u256 = 1000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    // Setup user1
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user1, amount);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(erc20_address, user1);
    token_dispatcher.approve(contract.contract_address, amount);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, user1);
    contract.create_asset(erc20_address, 300, 'STK');
    stop_cheat_caller_address(contract.contract_address);

    // Setup user2
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user2, amount);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(erc20_address, user2);
    token_dispatcher.approve(contract.contract_address, amount);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, user2);
    contract.create_asset(erc20_address, 500, 'STK');
    stop_cheat_caller_address(contract.contract_address);

    start_cheat_caller_address(contract.contract_address, owner);
    let balance1 = contract.get_balance(user1, erc20_address);
    let balance2 = contract.get_balance(user2, erc20_address);
    stop_cheat_caller_address(contract.contract_address);

    assert(balance1 == 300, 'User1 balance should be 300');
    assert(balance2 == 500, 'User2 balance should be 500');
}

#[test]
fn test_get_target_savings_success() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);
    let goal = 500_u256;
    let deadline = get_block_timestamp() + 1000;

    // Give user tokens and approve
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, 1000_u256);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, 1000_u256);
    stop_cheat_caller_address(erc20_address);

    // User creates asset and target
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, 500_u256, 'STK');
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);

    // No contributions yet
    let (ret_goal, ret_saved, ret_deadline) = contract.get_target_savings(user, target_id);
    assert(ret_goal == goal, 'Goal mismatch');
    assert(ret_saved == 0_u256, 'Saved should be zero');
    assert(ret_deadline == deadline, 'Deadline mismatch');

    // Contribute to target
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 200_u256);
    stop_cheat_caller_address(contract.contract_address);
    let (_, ret_saved2, _) = contract.get_target_savings(user, target_id);
    assert(ret_saved2 == 200_u256, 'Saved target should be 200');

    // Contribute again
    start_cheat_caller_address(contract.contract_address, user);
    contract.contribute_to_target(erc20_address, target_id, 300_u256);
    stop_cheat_caller_address(contract.contract_address);
    let (_, ret_saved3, _) = contract.get_target_savings(user, target_id);
    assert(ret_saved3 == 500_u256, 'Saved target should be 500');
}

#[test]
#[should_panic(expected: 'User does not own this target')]
fn test_get_target_savings_unauthorized() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);
    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    // User creates target
    start_cheat_caller_address(contract.contract_address, user);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);
    // Owner tries to access user's target
    contract.get_target_savings(owner, target_id);
}

#[test]
#[should_panic(expected: 'User does not own this target')]
fn test_get_target_savings_nonexistent_target_for_user() {
    let owner = OWNER();
    let user = NON_OWNER();
    let (contract, erc20_address) = setup(owner);
    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    // User creates target
    start_cheat_caller_address(contract.contract_address, user);
    let _target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);
    // User tries to access a target they don't own (id 999)
    contract.get_target_savings(user, 999_u64);
}

#[test]
#[should_panic(expected: 'Called with the zero address')]
fn test_get_target_savings_zero_user_address() {
    let owner = OWNER();
    let (contract, erc20_address) = setup(owner);
    let goal = 100_u256;
    let deadline = get_block_timestamp() + 100;
    // Owner creates target
    start_cheat_caller_address(contract.contract_address, owner);
    let target_id = contract.create_target(erc20_address, goal, deadline);
    stop_cheat_caller_address(contract.contract_address);
    // Call with zero address
    contract.get_target_savings(ZERO(), target_id);
}

#[test]
fn test_lock_savings_success() {
    let owner = OWNER();
    let user = NON_OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = amount;
    let total_approval: u256 = large_amount + create_amount;
    let lock_duration = 459;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let mut spy = spy_events();

    // Give user tokens and they should approve piggy contract
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, total_approval);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, total_approval);
    stop_cheat_caller_address(erc20_address);

    // User actions: Create asset -> deposit (optional) -> lock
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    let balance = contract.get_balance(user, erc20_address); // lock all user balance
    let lock_id = contract.lock_savings(erc20_address, balance, lock_duration);
    stop_cheat_caller_address(contract.contract_address);

    // Verify savings was locked
    let expected_unlock_time = get_block_timestamp() + lock_duration;
    let (locked_amount, unlock_time) = contract.get_locked_balance(user, erc20_address, lock_id);
    assert(locked_amount == balance, 'Locked amount mismatch');
    assert(unlock_time > 0, 'Invalid unlock time');
    assert(unlock_time == expected_unlock_time, 'Unlock time mismatch');

    // Verify events were emitted
    let expected_lock_event = Event::Locked(
        Locked { caller: user, token: erc20_address, amount: balance, lock_id, lock_duration },
    );
    spy.assert_emitted(@array![(contract.contract_address, expected_lock_event)]);
}

#[test]
fn test_unlock_savings_success() {
    let owner = OWNER();
    let user = NON_OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = amount;
    let total_approval: u256 = large_amount + create_amount;
    let lock_duration = 459;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let mut spy = spy_events();

    // Give user tokens and they should approve piggy contract
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, total_approval);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, total_approval);
    stop_cheat_caller_address(erc20_address);

    // User actions: Create asset -> deposit (optional) -> lock
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);
    let balance = contract.get_balance(user, erc20_address); // lock all user balance
    let lock_id = contract.lock_savings(erc20_address, balance, lock_duration);
    stop_cheat_caller_address(contract.contract_address);

    // Advance time past lock duration
    start_cheat_block_timestamp(contract.contract_address, lock_duration);

    // Unlock savings
    start_cheat_caller_address(contract.contract_address, user);
    contract.unlock_savings(erc20_address, lock_id);

    // Verify events were emitted
    let expected_unlock_event = Event::Unlocked(
        Unlocked { caller: user, token: erc20_address, amount: balance, lock_id },
    );

    spy.assert_emitted(@array![(contract.contract_address, expected_unlock_event)]);

    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_get_locked_balance() {
    let owner = OWNER();
    let user = NON_OWNER();
    let amount: u256 = 1000;
    let large_amount: u256 = 1_000_000; // Use a more reasonable amount
    let create_amount: u256 = amount;
    let total_approval: u256 = large_amount + create_amount;
    let lock_duration = 459;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    let (initial_locked_amout, initial_unlocked_time) = contract
        .get_locked_balance(user, erc20_address, 1);
    assert(initial_locked_amout == 0, 'Wrong initial locked amount');
    assert(initial_unlocked_time == 0, 'Wrong initial unlock time');

    // Give user tokens and they should approve piggy contract
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.transfer(user, total_approval);
    stop_cheat_caller_address(erc20_address);
    start_cheat_caller_address(erc20_address, user);
    token_dispatcher.approve(contract.contract_address, total_approval);
    stop_cheat_caller_address(erc20_address);

    // User actions: Create asset -> deposit (optional) -> lock
    start_cheat_caller_address(contract.contract_address, user);
    contract.create_asset(erc20_address, create_amount, 'STK');
    contract.deposit(erc20_address, large_amount);

    // Lock savings
    let balance = contract.get_balance(user, erc20_address); // lock all user balance
    let lock_id = contract.lock_savings(erc20_address, balance, lock_duration);

    // Get locked balance
    let (locked_amount, unlock_time) = contract.get_locked_balance(user, erc20_address, lock_id);

    assert(locked_amount == balance, 'Locked amount mismatch');
    assert(unlock_time > 0, 'Invalid unlock time');
}


