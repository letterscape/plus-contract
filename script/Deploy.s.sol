pragma solidity ^0.8.20;

import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import "../src/PoolFactory.sol";
import "../src/Swaplus.sol";
import "../src/CustomToken.sol";

contract DeployScript is Script {

  PoolFactory public factory;
  Swaplus public sp;
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

    initTokens();

    vm.stopBroadcast();
  }

  function initTokens() public {
    address to = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken token = new CustomToken(tokens[i], tokens[i]);
      console.log("create token[%s]: %s", tokens[i], address(token));
      token.mint(to, 10000 * 1e18);
    }
  }
}