pragma solidity ^0.8.20;

import "./Swaplus.sol";

contract Vault {
  Swaplus swaplus;
  IERC20 token;
  mapping(address account => uint256) public balances;

  event Deposit(address indexed depositor, uint256 amount);

  constructor(address _swaplus, address _token) {
    swaplus = Swaplus(_swaplus);
    token = IERC20(_token);
  }


  function deposit(uint256 amount) public returns (bool) {
    address sender = msg.sender;
    balances[sender] += amount;
    bool success = token.transferFrom(msg.sender, address(this), amount);
    if (success) {
        emit Deposit(sender, amount);
    }
    return success;
  }

  function withdraw(uint256 amount) external returns (bool){
    balances[msg.sender] -= amount;
    return token.transfer(msg.sender, amount);
  }

  function balanceOf(address account) external view returns (uint) {
    return balances[account];
  }

  function addLiquidity(
      address[] memory groupA, 
      address[] memory groupB, 
      uint[] memory amountsADesired,
      uint[] memory amountsBDesired,
      uint[] memory amountsAMin,
      uint[] memory amountsBMin,
      address to,
      uint deadline
  ) external {
    swaplus.addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin, to, deadline);
  }
}