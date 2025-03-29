pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import "../src/PoolFactory.sol";

contract PoolFactoryTest is Test {
  PoolFactory public factory;

  address[] groupX;
  address[] groupY;

  function setUp() public {
    factory = new PoolFactory();
  }

  function test_createPool() public {
    groupX.push(vm.addr(1));
    groupX.push(vm.addr(2));
    groupX.push(vm.addr(3));
    groupY.push(vm.addr(4));
    groupY.push(vm.addr(5));
    groupY.push(vm.addr(6));

    address pool = factory.createPool(groupX, groupY);
    // bytes32 indexX = keccak256(abi.encode(groupX));
    // bytes32 indexY = keccak256(abi.encode(groupY));

    address poolGot = factory.getPools(groupX, groupY);
    assertEq(pool, poolGot);
  }

  function test_getAllPools() public {
    
    address[] memory pools = new address[](10);
    for (uint256 i = 0; i < 10; i++) {
      pools[i] = createPool(i * 6);
    }

    uint256 len = factory.allPoolsLength();
    for (uint256 i = 0; i < len; i++) {
      address pool = factory.allPools(i);
      console.log('pool%s: %s', i, pool);
      assertEq(pools[i], pool);
    }
  }

  function createPool(uint256 i) public returns (address pool) {
    groupX.push(vm.addr(1 + i));
    groupX.push(vm.addr(2 + i));
    groupX.push(vm.addr(3 + i));
    groupY.push(vm.addr(4 + i));
    groupY.push(vm.addr(5 + i));
    groupY.push(vm.addr(6 + i));

    pool = factory.createPool(groupX, groupY);
    console.log('pool %s created', pool);
    return pool;
  }
}
