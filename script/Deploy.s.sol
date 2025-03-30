pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import "../src/PoolFactory.sol";
import "../src/Swaplus.sol";
import "../src/CustomToken.sol";
import "../src/Vault.sol";

contract DeployScript is Script {

  PoolFactory public factory;
  Swaplus public sp;
  Vault public vault;
  string[] public tokens = 
  [
    "WETH", "USDT", "USDC", "DAI", "AAVE", 
    "MKR", "PEPE", "1INCH", "BLUR", 
    "COMP", "CRV",
    "DYDX", "EIGEN",
    "ENA", "ENS", "ETHFI", "GRT",
    "GTC", "INJ", "LINK", 
    "MOVE", "OMNI", "POL", 
    "QUICK", "SHIB", "SNX",
    "SOL", "STRK", "SUSHI",
    "WBTC", "ZRX", "SAND", "REN"
  ];

  function run() public {
    vm.startBroadcast();
    
    factory = new PoolFactory();
    console.log("create factory contract: ", address(factory));

    sp = new Swaplus(address(factory));
    console.log("create Swaplus contract: ", address(sp));

    address usdc = initTokens();

    vault = new Vault(address(sp), usdc, address(factory));
    console.log("create Vault contract: ", address(vault));

    vm.stopBroadcast();
  }

  function initTokens() public returns(address usdt) {
    // dev
    address to = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    // test
    // address to = 0xD571Cb930A525c83D7D2B7442a34b09c5F1cCa3E;
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken token = new CustomToken(tokens[i], tokens[i]);
      console.log("create token[%s]: %s", tokens[i], address(token));
      token.mint(to, 10000 * 1e18);
      if (isEqaul(tokens[i], "USDT")) usdt = address(token);
    }
  }

  function isEqaul(string memory a,string memory b) public view returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }
}