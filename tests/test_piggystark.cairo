use piggystark::interfaces::ipiggystark::{IPiggyStarkDispatcher, IPiggyStarkDispatcherTrait};
use core::traits::{Into, TryInto};

use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, test_address,  start_cheat_block_timestamp,  stop_cheat_block_timestamp,
};
use starknet::{ContractAddress, contract_address_const};
use piggystark::contracts::piggystark::PiggyStark::{
    Event, SuccessfulDeposit, AssetCreated, Withdrawal, Locked, Unlocked, NostraDeposit, NostraWithdrawal,
};
use piggystark::interfaces::inostra::{INostraDispatcher, INostraDispatcherTrait};
// use snforge_std::{
//     CheatSpan, EventSpyAssertionsTrait, cheat_block_timestamp, cheat_caller_address, spy_events,
// };

fn NOSTRA() -> ContractAddress {
    contract_address_const::<'NOSTRA'>()
}

fn setup(owner: ContractAddress) -> (IPiggyStarkDispatcher, ContractAddress) {
    // Deploy mock ERC20
    let erc20_class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 18];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    let nostra: ContractAddress = NOSTRA();
    let contract_class = declare("PiggyStark").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into(), nostra.into()]).unwrap();
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
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

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
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';
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
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

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
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let token_name: felt252 = 'STRK';

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
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    let allowance = token_dispatcher.allowance(owner, contract.contract_address);
    assert(allowance == amount, 'Allowance not set correctly');
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 100, 'STRK');
    contract.deposit(erc20_address, (amount/2));
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_none_existing_token_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

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
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 0);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_insufficient_deposit_allowance() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, amount);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_multiple_deposit() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let amount2: u256 = 200_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.deposit(erc20_address, amount2);
    contract.deposit(erc20_address, amount2);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 800, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);

    // // Need to approve the contract to transfer back during withdraw
    // start_cheat_caller_address(erc20_address, owner);
    // token_dispatcher.approve(contract.contract_address, amount);
    // stop_cheat_caller_address(erc20_address);
    
    contract.withdraw(erc20_address, 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
fn test_successful_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.withdraw(erc20_address, 345);
    contract.withdraw(erc20_address, 500_000);
    contract.withdraw(erc20_address, 100_000_000);
    contract.withdraw(erc20_address, 400);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Amount overflows balance')]
fn test_balance_overflow_multiple_withdraw() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, 100_000_000_000_000_000_000_000);
    contract.withdraw(erc20_address, amount);
    contract.withdraw(erc20_address, 500_000);
    stop_cheat_caller_address(contract.contract_address);
}

#[test]
#[should_panic(expected: 'Asset does not exist')]
fn test_withdraw_from_non_existing_user_token() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

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
#[should_panic(expected: 'Zero Address Caller')]
fn test_withdraw_from_Zero_caller_address() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;
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
    let amount: u256 = 200_000_000_000_000_000_000_000;
    let deposit_amount: u256 = amount / 2;

    let (contract, erc20_address) = setup(owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve(contract.contract_address, amount);
    token_dispatcher.allowance(owner, contract.contract_address);
    stop_cheat_caller_address(erc20_address);

    start_cheat_caller_address(contract.contract_address, owner);
    contract.create_asset(erc20_address, 300, 'STRK');
    contract.deposit(erc20_address, deposit_amount);
    let token_balance = contract.get_token_balance(erc20_address);
    stop_cheat_caller_address(contract.contract_address);

    let expected_balance = deposit_amount + 300;
    assert(token_balance == expected_balance, ERRORS().INCORRECT_BALANCE);
}

#[test]
#[should_panic(expected: 'User does not possess token')]
fn test_get_token_balance_for_none_exist_user_token() {
    let owner = OWNER();
    let amount: u256 = 200_000_000_000_000_000_000_000;

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
    let amount: u256 = 200_000_000_000_000_000_000_000;
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

// #[test]
// fn test_get_user_assets() {
//     let owner = OWNER();
//     let amount: u256 = 200_000_000_000_000_000_000_000;

//     let (contract, erc20_address) = setup(owner);
//     let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

//     start_cheat_caller_address(erc20_address, owner);
//     token_dispatcher.approve(contract.contract_address, amount);
//     token_dispatcher.allowance(owner, contract.contract_address);
//     stop_cheat_caller_address(erc20_address);

//     start_cheat_caller_address(contract.contract_address, owner);
//     contract.create_asset(erc20_address, 300, 'STRK');
//     let user_assets = contract.get_user_assets();
//     stop_cheat_caller_address(contract.contract_address);
//     assert(user_assets.len() > 0, ERRORS().NO_TOKENS_AVAILABLE);
// }

// #[test]
// fn test_get_user_assets_no_token() {
//     let owner = OWNER();
//     let amount: u256 = 200_000_000_000_000_000_000_000;

//     let (contract, erc20_address) = setup(owner);
//     let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };

//     start_cheat_caller_address(erc20_address, owner);
//     token_dispatcher.approve(contract.contract_address, amount);
//     token_dispatcher.allowance(owner, contract.contract_address);
//     stop_cheat_caller_address(erc20_address);

//     start_cheat_caller_address(contract.contract_address, owner);
//     let user_assets = contract.get_user_assets();
//     stop_cheat_caller_address(contract.contract_address);
//     assert(user_assets.len() == 0, ERRORS().SHOULD_HAVE_NO_TOKENS);
// }

fn deploy() -> IPiggyStarkDispatcher {
    let nostra_contract = NOSTRA();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    nostra_contract.serialize(ref calldata);

    let class = declare("PiggyStark").unwrap().contract_class();
    let (contract_address, _) = class.deploy(@calldata).unwrap();
    (IPiggyStarkDispatcher { contract_address })
}

fn deploy_nostra() -> ContractAddress {
    let class = declare("Nostra").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = class.deploy(@calldata).unwrap();
    contract_address
}

fn erc20() ->  IERC20Dispatcher  {
    let class = declare("STARKTOKEN").unwrap().contract_class();
    let mut calldata = array![OWNER().into(), OWNER().into(), 18];
    let (contract_address, _) = class.deploy(@calldata).unwrap();
    IERC20Dispatcher { contract_address: contract_address }
}

#[test]
fn test_lock_savings_with_nostra_success() {
    let dispatcher = deploy();
    let token = erc20();
    let amount = 1_000_000;
    let lock_duration = 459;

    start_cheat_caller_address(token.contract_address, OWNER());
    token.approve(dispatcher.contract_address, amount * 2);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.create_asset(token.contract_address, amount, 'STARK');

    // Lock savings
    // let spy = spy_events();
    let lock_id = dispatcher.lock_savings(token.contract_address, amount, lock_duration);

    // Verify lock was created
    let (locked_amount, unlock_time) = dispatcher.get_locked_balance(OWNER(), token.contract_address, lock_id);
    assert(locked_amount == amount, 'Locked amount mismatch');
    assert(unlock_time > 0, 'Invalid unlock time');

    // Verify Nostra deposit
    // let nostra_dispatcher = INostraDispatcher { contract_address: nostra_contract };
    // let nostra_balance = nostra_dispatcher.get_user_yield(USER(), token);
    // assert(nostra_balance > 0, 'No yield generated in Nostra');

    // Verify events were emitted
    // let events = array![
    //     (dispatcher.contract_address, Event::Locked(Locked { caller: USER(), token, amount, lock_id, lock_duration })),
    //     (dispatcher.contract_address, Event::NostraDeposit(NostraDeposit { caller: USER(), token, amount, lock_id }))
    // ];
    // spy.assert_emitted(@events);
}

#[test]
fn test_unlock_savings_with_nostra_success() {
    let dispatcher = deploy();
    let token = erc20();
    let amount = 1_000_000;
    let lock_duration = 100;

    // Setup: Create asset and deposit tokens
    start_cheat_caller_address(token.contract_address, OWNER());
    token.approve(dispatcher.contract_address, amount);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.create_asset(token.contract_address, amount, 'STARK');

    // Lock savings
    let lock_id = dispatcher.lock_savings(token.contract_address, amount, lock_duration);

    // Advance time past lock duration
    start_cheat_block_timestamp(dispatcher.contract_address, lock_duration + 9);

    // Unlock savings
    // let spy = spy_events(dispatcher.contract_address);
    dispatcher.unlock_savings(token.contract_address, lock_id);

    // Verify lock was removed
    let (locked_amount, _) = dispatcher.get_locked_balance(OWNER(), token.contract_address, lock_id);
    assert(locked_amount == 0, 'Lock still active');

    // Verify Nostra withdrawal
    // let nostra_dispatcher = INostraDispatcher { contract_address: nostra_contract };
    // let nostra_balance = nostra_dispatcher.get_user_yield(USER(), token);
    // assert(nostra_balance == 0, 'Funds still in Nostra');

    // // Verify events were emitted
    // let events = array![
    //     (dispatcher.contract_address, Event::Unlocked(Unlocked { caller: USER(), token, amount, lock_id })),
    //     (dispatcher.contract_address, Event::NostraWithdrawal(NostraWithdrawal { caller: USER(), token, amount, lock_id }))
    // ];
    // spy.assert_emitted(@events);
}

// #[test]
// #[should_panic(expected: ('Failed to deposit to Nostra', ))]
// fn test_lock_savings_nostra_deposit_failure() {
//     let (dispatcher, _) = deploy();
//     let token = erc20();
//     let amount = 1000;
//     let lock_duration = 100;

//     // Setup: Create asset and deposit tokens
//     cheat_caller_address(token, OWNER(), CheatSpan::TargetCalls(1));
//     let token_dispatcher = IERC20Dispatcher { contract_address: token };
//     token_dispatcher.transfer(USER(), amount);

//     cheat_caller_address(token, USER(), CheatSpan::TargetCalls(1));
//     token_dispatcher.approve(dispatcher.contract_address, amount);

//     cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
//     dispatcher.create_asset(token, amount, 'STARK');

//     // Lock savings - should fail due to Nostra deposit failure
//     dispatcher.lock_savings(token, amount, lock_duration);
// }

// #[test]
// #[should_panic(expected: ('Failed to withdraw from Nostra', ))]
// fn test_unlock_savings_nostra_withdrawal_failure() {
//     let (dispatcher, _) = deploy();
//     let token = erc20();
//     let amount = 1000;
//     let lock_duration = 100;

//     // Setup: Create asset and deposit tokens
//     cheat_caller_address(token, OWNER(), CheatSpan::TargetCalls(1));
//     let token_dispatcher = IERC20Dispatcher { contract_address: token };
//     token_dispatcher.transfer(USER(), amount);

//     cheat_caller_address(token, USER(), CheatSpan::TargetCalls(1));
//     token_dispatcher.approve(dispatcher.contract_address, amount);

//     cheat_caller_address(dispatcher.contract_address, USER(), CheatSpan::Indefinite);
//     dispatcher.create_asset(token, amount, 'STARK');

//     // Lock savings
//     let lock_id = dispatcher.lock_savings(token, amount, lock_duration);

//     // Advance time past lock duration
//     cheat_block_timestamp(dispatcher.contract_address, lock_duration + 1, CheatSpan::Indefinite);

//     // Unlock savings - should fail due to Nostra withdrawal failure
//     dispatcher.unlock_savings(token, lock_id);
// }
