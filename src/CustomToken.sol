pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CustomToken is ERC20 {

  constructor(
    string memory _name, 
    string memory _symbol) ERC20(_name, _symbol) {
      _mint(address(this), 1e32);
  }

  function mint(address to, uint amount) public {
    _mint(to, amount);
  }
}