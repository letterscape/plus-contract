// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IPoolFactory.sol";
import "./SwapPool.sol";

contract PoolFactory is IPoolFactory {
  uint256 public constant GROUP_TOKEN_NUMBER_MAX = 100;

  mapping(bytes32 => mapping(bytes32 => address)) public pools;
  address[] public allPools;

  function createPool(
    address[] calldata groupA,
    address[] calldata groupB
  ) external returns (address pool) {
    checkTokenAddress(groupA, groupB);
    bytes32 bytesA = keccak256(abi.encode(groupA));
    bytes32 bytesB = keccak256(abi.encode(groupB));
    (bytes32 bytesX, bytes32 bytesY, address[] memory groupX, address[] memory groupY) = bytesA < bytesB ? (bytesA, bytesB, groupA, groupB) : (bytesB, bytesA, groupB, groupA);
    require(pools[bytesX][bytesY] == address(0), "SwaplusV1: POOL_EXISTS");

    bytes memory bytecode = type(SwapPool).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(bytesX, bytesY));
    assembly {
      pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
    ISwapPool(pool).initialize(groupX, groupY);
    pools[bytesX][bytesY] = pool;
    pools[bytesY][bytesX] = pool;
    allPools.push(pool);
    emit PoolCreated(groupX, groupY, pool, allPools.length);
  }

  function getPools(address[] calldata groupA, address[] calldata groupB) public view returns (address pool) {
    pool = pools[keccak256(abi.encode(groupA))][keccak256(abi.encode(groupB))];
  }

  function allPoolsLength() external view returns (uint) {
    return allPools.length;
  }

  function checkTokenAddress(
    address[] memory groupX,
    address[] memory groupY
  ) public pure {
    uint256 groupXLen = groupX.length;
    uint256 groupYLen = groupY.length;
    require(
      groupXLen <= GROUP_TOKEN_NUMBER_MAX && groupYLen <= groupYLen,
      "SwaplusV1: TOKEN_NUMBER_REACH_LIMIT"
    );
    for (uint256 i = 0; i < groupXLen; i++) {
      for (uint256 j = 0; j < groupYLen; j++) {
        require(groupX[i] != groupY[j], "SwaplusV1: IDENTICAL_TOKEN_ADDRESSES");
      }
      require(groupX[i] != address(0), "SwaplusV1: ZERO_TOKEN_ADDRESS");
    }
  }
}
