// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

interface IPoolFactory {
  event PoolCreated(
    address[] groupX, address[] groupY, address indexed pool, uint256
  );

  function createPool(address[] calldata groupA, address[] calldata groupB) external returns (address pool);

  function getPools(address[] calldata groupA, address[] calldata groupB) external returns (address pool);
  function allPools(uint) external view returns (address pool);
  function allPoolsLength() external view returns (uint);
}
