// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {

	Token private tokenContract;
    uint public interestRate = 3168808781;  // 1e17 (10% APY of 1ETH) / 31557600 (sec in 365.25 days)

    mapping(address => bool) public hasDeposited;
    mapping(address => uint) public depositStart;
    mapping(address => uint) public etherBalanceOf;

    event Deposit(address indexed user, uint amount, uint time);
    event Withdraw(address indexed user, uint amount, uint time, uint interest);
    event Borrow(uint amount);
    event PayOff(uint amount);

	constructor(Token _tokenContract) {
        tokenContract = _tokenContract;
    }

	function deposit() payable public {
        require(!hasDeposited[msg.sender], "User already has an active deposit");
		require(msg.value >= 10 ** 16, "The value must be greater then 0.01 ETH");

		etherBalanceOf[msg.sender] =   msg.value;
        hasDeposited[msg.sender] = true;

        depositStart[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, msg.value, block.timestamp);
	}

	function withdraw() public {
		require(hasDeposited[msg.sender], "Did not make any deposits yet");
		uint balance = etherBalanceOf[msg.sender];

		uint time = block.timestamp - depositStart[msg.sender];
		uint interest = time * interestRate * etherBalanceOf[msg.sender] / 1e18;

		msg.sender.transfer(balance);
		tokenContract.mint(msg.sender, interest);

        etherBalanceOf[msg.sender] = 0;
        hasDeposited[msg.sender] = false;
        depositStart[msg.sender] = 0;

		emit Withdraw(msg.sender, balance, block.timestamp, interest);
	}

	function borrow(uint _amount) payable public {
		//check if collateral is >= than 0.01 ETH
		//check if user doesn't have active loan

		//add msg.value to ether collateral

		//calc tokens amount to mint, 50% of msg.value

		//mint&send tokens to user

		//activate borrower's loan status

		//emit event
	}

	function payOff(uint _amount) public {
		//check if loan is active
		//transfer tokens from user back to the contract

		//calc fee

		//send user's collateral minus fee

		//reset borrower's data

		//emit event
	}
}