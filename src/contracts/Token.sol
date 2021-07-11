// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    address public minter;

    event MinterChange(address _from, address _to);

    constructor(string memory _name, string memory _symbol) payable ERC20(_name, _symbol) {
        minter = msg.sender;
    }

    function changeMinter(address _to) public {
        require(msg.sender == minter, "Must be the minter to call the function");
        minter = _to;
        emit MinterChange(msg.sender, _to);
    }

    function mint(address account, uint256 amount) public {
        require(msg.sender == minter, "Must be the minter to call the function");
		_mint(account, amount);
	}
}