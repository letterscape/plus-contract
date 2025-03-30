// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "./WrapSafeMath.sol";
import "../interfaces/ISwapPool.sol";
import "../SwapPool.sol";
import { console } from "forge-std/Test.sol";

library SwaplusV1Library {

  using WrapSafeMath for uint;

  function sortTokens(address[] memory groupA, address[] memory groupB) internal pure returns (bytes32 bytesX, bytes32 bytesY, address[] memory groupX, address[] memory groupY) {
    checkTokenAddress(groupA, groupB);
    bytes32 bytesA = keccak256(abi.encode(groupA));
    bytes32 bytesB = keccak256(abi.encode(groupB));
    (bytesX, bytesY, groupX, groupY) = bytesA < bytesB ? (bytesA, bytesB, groupA, groupB) : (bytesB, bytesA, groupB, groupA);
  
  }

  function getPool(address factory, address[] memory groupA, address[] memory groupB) public pure returns (address pool) {
    bytes memory bytecode = type(SwapPool).creationCode;
    bytes32 initCodeHash = keccak256(bytecode);
    (bytes32 tokensX, bytes32 tokensY, , ) = sortTokens(groupA, groupB);
    pool = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(tokensX, tokensY)),
                initCodeHash // init code hash
            )))));
    
  }

  function getVirtualReserveSum(
    address factory, 
    address[] memory groupA, 
    address[] memory groupB) internal view returns (uint reserveA, uint reserveB) {
    
    (uint sumX, uint sumY) = ISwapPool(getPool(factory, groupA, groupB)).getVirtualSum();
    (bytes32 bytesA, , ,) = sortTokens(groupA, groupB);
    (reserveA, reserveB) = bytesA == keccak256(abi.encode(groupA)) ? (sumX, sumY) : (sumY, sumX);
  }

  function getVirtualReserves(address factory, 
    address[] memory groupA, 
    address[] memory groupB, 
    address[] memory tokensA,
    address[] memory tokensB
  ) internal view returns (
    uint virtualAsum,
    uint virtualBsum,
    uint[] memory virtualAs, 
    uint[] memory virtualBs
  ) {
    (virtualAsum, virtualBsum, virtualAs, virtualBs) = ISwapPool(getPool(factory, groupA, groupB)).getVirtuals(tokensA, tokensB);
  }

  function sum(uint[] memory amounts) internal pure returns (uint res) {
    for (uint i = 0; i < amounts.length; i++) {
      res += amounts[i];
    }
  }

  function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
    require(amountA > 0, 'SwaplusV1Library: INSUFFICIENT_AMOUNT');
    require(reserveA > 0 && reserveB > 0, 'SwaplusV1Library: INSUFFICIENT_LIQUIDITY');
    amountB = amountA.mul(reserveB) / reserveA;
  }

  function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
    require(amountIn > 0, 'SwaplusV1Library: INSUFFICIENT_INPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'SwaplusV1Library: INSUFFICIENT_LIQUIDITY');
    //todo fee
    uint amountInWithFee = amountIn;
    uint numerator = amountInWithFee.mul(reserveOut);
    uint denominator = reserveIn.add(amountInWithFee);
    amountOut = numerator / denominator;
  }

  function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
    require(amountOut > 0, 'SwaplusV1Library: INSUFFICIENT_OUTPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'SwaplusV1Library: INSUFFICIENT_LIQUIDITY');
    //todo fee
    uint numerator = reserveIn.mul(amountOut);
    uint denominator = reserveOut.sub(amountOut);
    amountIn = numerator.ceilDiv(denominator);
  }

  // groupIn和groupOut用于获取pool，tokensIn和tokensOut分别是groupIn和groupOut的子集
  function getAmountsOut(
    address factory,
    address[] memory groupIn, 
    address[] memory groupOut,
    address[] memory tokensIn, 
    address[] memory tokensOut,
    uint[] memory amountsIn
  ) internal view returns (uint[] memory amountsOut) {
    require(tokensIn.length == amountsIn.length, 'SwaplusV1Library: INCONSISTENT_AMOUNTS_IN');
    (uint reservesASum, uint reservesBSum) = getVirtualReserveSum(factory, groupIn, groupOut);
    (uint reservesInSum, uint reservesOutSum, uint[] memory reservesIn, uint[] memory reservesOut) = getVirtualReserves(factory, groupIn, groupOut, groupIn, tokensOut);
    uint sumIn = sum(amountsIn);
    uint amountIn = sumIn.mul(reservesIn[0]).ceilDiv(reservesInSum);
    uint amountOut = getAmountOut(amountIn, reservesIn[0], reservesOut[0]);
    uint sumOut = amountOut.mul(reservesBSum).ceilDiv(reservesOut[0]);
    amountsOut = new uint[](tokensOut.length);
    console.log("sumOut", sumOut);
    for(uint i = 0; i < tokensOut.length; i++) {
      amountsOut[i] = sumOut.mul(reservesOut[i]).ceilDiv(reservesOutSum);
    }
  }

  function getAmountsIn(
    address factory,
    address[] memory groupIn, 
    address[] memory groupOut,
    address[] memory tokensIn, 
    address[] memory tokensOut,
    uint[] memory amountsOut
  ) internal view returns (uint[] memory amountsIn) {
    require(tokensOut.length == amountsOut.length, 'SwaplusV1Library: INCONSISTENT_AMOUNTS_OUT');
    (uint reservesASum, uint reservesBSum) = getVirtualReserveSum(factory, groupIn, groupOut);
    (uint reservesInSum, uint reservesOutSum, uint[] memory reservesIn, uint[] memory reservesOut) = getVirtualReserves(factory, groupIn, groupOut, tokensIn, groupOut);
    uint sumOut = sum(amountsOut);
    uint amountOut = sumOut.mul(reservesOut[0]).ceilDiv(reservesOutSum);
    uint amountIn = getAmountIn(amountOut, reservesIn[0], reservesOut[0]);
    uint sumIn = amountIn.mul(reservesASum).ceilDiv(reservesIn[0]);
    amountsIn = new uint[](tokensIn.length);
    for(uint i = 0; i < tokensIn.length; i++) {
      amountsIn[i] = sumIn.mul(reservesIn[i]).ceilDiv(reservesInSum);
    }
  }

  function checkTokenAddress(
    address[] memory groupA,
    address[] memory groupB
  ) public pure {
    uint256 groupALen = groupA.length;
    uint256 groupBLen = groupB.length;
    for (uint256 i = 0; i < groupALen; i++) {
      for (uint256 j = 0; j < groupBLen; j++) {
        require(groupA[i] != groupB[j], "SwaplusV1: IDENTICAL_TOKEN_ADDRESSES");
        require(groupB[j] != address(0), "SwaplusV1: ZERO_TOKEN_ADDRESS");
      }
      require(groupA[i] != address(0), "SwaplusV1: ZERO_TOKEN_ADDRESS");
    }
  }
}