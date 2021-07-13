// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Token.sol";

contract dBank {

	Token private tokenContract;
	uint public conversionRate = 1;  // tokens for 1 ether
    uint public secoundsInYear = 31557600;  // sec in 365.25 days
	uint16 public collateral = 8000;  // 80%
	uint16 public etherAPY = 1000;  // 10%
	uint16 public tokenAPY = 1500;  // 15%
	uint16 public etherAPR = 2000;  // 20%
	uint16 public tokenAPR = 2000;  // 20%

    mapping(address => bool) public hasDepositedEther;
    mapping(address => bool) public hasDepositedToken;
    mapping(address => uint) public etherBalanceOf;
    mapping(address => uint) public tokenBalanceOf;
	mapping(address => uint) public availableValueOf;

    mapping(address => uint) public depositEtherStart;
    mapping(address => uint) public depositTokenStart;
	mapping(address => uint) public unpayedInterestForEther;
	mapping(address => uint) public unpayedInterestForToken;

	mapping(address => bool) public hasBorrowedEther;
	mapping(address => bool) public hasBorrowedToken;
	mapping(address => uint) public etherBorrowedBy;
	mapping(address => uint) public tokenBorrowedBy;

	mapping(address => uint) public loanEtherStart;
	mapping(address => uint) public loanTokenStart;
	mapping(address => uint) public dueInterestForEther;
	mapping(address => uint) public dueInterestForToken;

	uint public totalEtherDeposited;
	uint public totalTokenDeposited;

    event Deposit(address indexed user, uint amountEther, uint amountToken, uint time);
	event Harvest(address indexed user, uint interest, uint time);
    event Withdraw(address indexed user, uint amountEther, uint amountToken, uint interest, uint time);
    event Borrow(address indexed user, uint amountEther, uint amountToken, uint time);
    event PayOff(address indexed user, uint amountEther, uint amountToken, uint interest, uint time);

	constructor(Token _tokenContract) {
        tokenContract = _tokenContract;
    }

	function calculateInterestForEtherDeposited(address _account) internal {
		uint time = block.timestamp - depositEtherStart[_account];
		uint interest = time * etherBalanceOf[_account] * etherAPY / (10000 * secoundsInYear) * conversionRate;
		unpayedInterestForEther[_account] += interest;
		depositEtherStart[msg.sender] = block.timestamp;
	}

	function calculateInterestForTokenDeposited(address _account) internal {
		uint time = block.timestamp - depositEtherStart[_account];
		uint interest = time * tokenBalanceOf[_account] * tokenAPY / (10000 * secoundsInYear);
		unpayedInterestForToken[_account] += interest;
		depositTokenStart[_account] = block.timestamp;
	}

	function calculateInterestForEtherBorrowed(address _account) internal {
		uint time = block.timestamp - depositEtherStart[_account];
		uint interest = time * etherBorrowedBy[_account] * etherAPR / (10000 * secoundsInYear) * conversionRate;
		dueInterestForEther[_account] += interest;
		loanEtherStart[msg.sender] = block.timestamp;
	}

	function calculateInterestForTokenBorrowed(address _account) internal {
		uint time = block.timestamp - depositEtherStart[_account];
		uint interest = time * tokenBorrowedBy[_account] * tokenAPR / (10000 * secoundsInYear);
		dueInterestForToken[_account] += interest;
		loanTokenStart[_account] = block.timestamp;
	}

	function payTokenTo(address _account, uint _amount) internal {
		if (totalTokenDeposited <= _amount) {
			tokenContract.transfer(_account, _amount);
			totalTokenDeposited -= _amount;
		} else {
			uint diffrence = _amount - totalTokenDeposited;
			tokenContract.transfer(_account, totalTokenDeposited);
			tokenContract.mint(msg.sender, diffrence);
			totalTokenDeposited = 0;
		}
	}

	function depositEther() payable public {
		require(msg.value >= 10 ** 16, "The value must be greater then 0.01 ETH");

		if (hasDepositedEther[msg.sender]) {
			calculateInterestForEtherDeposited(msg.sender);
		} else  {
			hasDepositedEther[msg.sender] = true;
			depositEtherStart[msg.sender] = block.timestamp;
		}
		etherBalanceOf[msg.sender] += msg.value;
		availableValueOf[msg.sender] += msg.value * conversionRate;
		
		totalEtherDeposited += msg.value;

        emit Deposit(msg.sender, msg.value, 0, block.timestamp);
	}

	function depositTokens(uint _amount) public {
		require(_amount>= 10 ** 16, "The value must be greater then 0.01 token");
		require(tokenContract.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

		if (hasDepositedToken[msg.sender]) {
			calculateInterestForTokenDeposited(msg.sender);
		} else  {
			hasDepositedToken[msg.sender] = true;
			depositTokenStart[msg.sender] = block.timestamp;
		}
		tokenBalanceOf[msg.sender] += _amount;
		availableValueOf[msg.sender] += _amount;

		totalTokenDeposited += _amount;

        emit Deposit(msg.sender, 0, _amount, block.timestamp);
	}

	function harvestInterestForEtherDeposited() public {
		require(hasDepositedEther[msg.sender], "Did not make any deposits yet");
		
		calculateInterestForEtherDeposited(msg.sender);
		require(unpayedInterestForEther[msg.sender] > 0, "Do not have any interest yet");
		
		tokenContract.mint(msg.sender, unpayedInterestForEther[msg.sender]);
		uint interest = unpayedInterestForEther[msg.sender];
		unpayedInterestForEther[msg.sender] = 0;

		emit Harvest(msg.sender, interest, block.timestamp);
	}

	function harvestInterestForTokenDeposited() public {
		require(hasDepositedToken[msg.sender], "Did not make any deposits yet");
		
		calculateInterestForTokenDeposited(msg.sender);
		require(unpayedInterestForToken[msg.sender] > 0, "Do not have any interest yet");
		
		payTokenTo(msg.sender, unpayedInterestForEther[msg.sender]);
		uint interest = unpayedInterestForEther[msg.sender];
		unpayedInterestForEther[msg.sender] = 0;
		
		emit Harvest(msg.sender, interest, block.timestamp);
	}

	function withdrawEther(uint _amount) public {
		require(hasDepositedEther[msg.sender], "Did not make any deposits yet");
		require(etherBalanceOf[msg.sender] >= _amount, "Withdraw amount is bigger the the balance");
		require(availableValueOf[msg.sender] >= _amount * conversionRate,
			"Withdraw amount is bigger the the available balance");
		require(totalEtherDeposited >= _amount, "Not enough funds available");
		require(etherBalanceOf[msg.sender] ==_amount || etherBalanceOf[msg.sender] - _amount >= 1e16,
			"The remaining balance is too small");
		
		calculateInterestForEtherDeposited(msg.sender);

		msg.sender.transfer(_amount);
		
		totalEtherDeposited -= _amount;
		availableValueOf[msg.sender] -= _amount;
        etherBalanceOf[msg.sender] -= _amount;

		uint payedInterest = 0;
		if (etherBalanceOf[msg.sender] == 0) {
        	hasDepositedEther[msg.sender] = false;
        	depositEtherStart[msg.sender] = 0;
			tokenContract.mint(msg.sender, unpayedInterestForEther[msg.sender]);
			payedInterest = unpayedInterestForEther[msg.sender];
			unpayedInterestForEther[msg.sender] = 0;
		}

		emit Withdraw(msg.sender, _amount,  0, payedInterest, block.timestamp);
	}

	function withdrawToken(uint _amount) public {
		require(hasDepositedToken[msg.sender], "Did not make any deposits yet");
		require(tokenBalanceOf[msg.sender] >= _amount, "Withdraw amount is bigger the the balance");
		require(availableValueOf[msg.sender] >= _amount, "Withdraw amount is bigger the the available balance");
		require(tokenBalanceOf[msg.sender] ==_amount || etherBalanceOf[msg.sender] - _amount >= 1e16,
			"The remaining balance is too small");
		
		calculateInterestForTokenDeposited(msg.sender);

		tokenContract.transfer(msg.sender, totalTokenDeposited);
		
		totalTokenDeposited -= _amount;
		tokenBalanceOf[msg.sender] -= _amount;
		availableValueOf[msg.sender] -= _amount;

		uint payedInterest = 0;
		if (tokenBalanceOf[msg.sender] == 0) {
			hasDepositedToken[msg.sender] = false;
			depositTokenStart[msg.sender] = 0;
			payTokenTo(msg.sender, unpayedInterestForToken[msg.sender]);
			payedInterest = 0;
			unpayedInterestForToken[msg.sender] = 0;
		}

		emit Withdraw(msg.sender, 0, _amount, payedInterest, block.timestamp);
	}

	function borrowEther(uint _amount) public {
		require(collateral * availableValueOf[msg.sender] * conversionRate >= 100 * _amount, "Balance too small");
		require(totalEtherDeposited >= _amount, "Not enough founds");

		msg.sender.transfer(_amount);

		if (hasBorrowedEther[msg.sender]) {
			calculateInterestForEtherBorrowed(msg.sender);
		} else {
			hasBorrowedEther[msg.sender] = true;
			loanEtherStart[msg.sender] = block.timestamp;
		}
		availableValueOf[msg.sender] -= _amount  * conversionRate * 10000 / collateral;
		etherBorrowedBy[msg.sender] -= _amount;

		totalEtherDeposited -= _amount;

		emit Borrow(msg.sender, _amount, 0, block.timestamp);
	}

	
	function borrowToken(uint _amount) public {
		require(collateral * availableValueOf[msg.sender] >= 100 * _amount, "Balance too small");

		payTokenTo(msg.sender, _amount);

		if (hasBorrowedToken[msg.sender]) {
			calculateInterestForTokenBorrowed(msg.sender);
		} else {
			hasBorrowedToken[msg.sender] = true;
			loanTokenStart[msg.sender] = block.timestamp;
		}
		availableValueOf[msg.sender] -= 10000 *_amount / collateral;
		tokenBorrowedBy[msg.sender] += _amount;

		emit Borrow(msg.sender, _amount, 0, block.timestamp);
	}

	function payOffEther() public payable {
		require(hasBorrowedEther[msg.sender], "No active loan");
		
		calculateInterestForEtherBorrowed(msg.sender);
		require(msg.value >= dueInterestForEther[msg.sender], "The amount does not cover the interest");

		uint payOff = msg.value - dueInterestForEther[msg.sender];
		if (payOff > etherBorrowedBy[msg.sender]) {
			msg.sender.transfer(payOff - etherBorrowedBy[msg.sender]);
			payOff = etherBorrowedBy[msg.sender];
		}
		dueInterestForEther[msg.sender] = 0;
		etherBorrowedBy[msg.sender] -= payOff;
		availableValueOf[msg.sender] += payOff  * conversionRate * 10000 / collateral;

		totalEtherDeposited += msg.value;

		if (etherBorrowedBy[msg.sender] == 0) {
			hasBorrowedEther[msg.sender] = false;
			loanEtherStart[msg.sender] = 0;
		}

		emit PayOff(msg.sender, payOff, 0, msg.value - payOff, block.timestamp);
	}

	function payOffToken(uint _amount) public payable {
		require(hasBorrowedToken[msg.sender], "No active loan");

		calculateInterestForTokenBorrowed(msg.sender);
		require(msg.value >= dueInterestForEther[msg.sender], "The amount does not cover the interest");

		uint interest = dueInterestForEther[msg.sender];
		if (msg.value > interest) {
			msg.sender.transfer(msg.value - interest);
		}
		dueInterestForEther[msg.sender] = 0;
		tokenBorrowedBy[msg.sender] -= _amount;
		availableValueOf[msg.sender] += 10000 *_amount / collateral;
		
		if (tokenBorrowedBy[msg.sender] == 0) {
			hasBorrowedToken[msg.sender] = false;
			loanTokenStart[msg.sender] = 0;
		}
	}
}