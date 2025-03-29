// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

interface ISwapPool {

  event Mint(uint indexed timestamp, address indexed sender, uint liquidity, address[] tokenXs, address[] tokenYs, uint[] amountXs, uint[] amountYs);
  event Sync1(uint indexed timestamp, address[] tokens, uint[] reserves);
  event Sync2(uint indexed timestamp, address[] tokenXs, address[] tokenYs, uint[] reserveXs, uint[] reserveYs);
  event Swap(
    uint indexed timestamp, 
    address indexed sender,
    address[] tokensOut,
    uint[] amountsXOut,
    uint[] amountsYOut,
    address indexed to
  );
  function initialize(
    address[] calldata _groupX,
    address[] calldata _groupY
  ) external;

  function getVirtualSum() external view returns (uint sumX, uint sumY);
  function getVirtuals(address[] memory tokenAs, address[] memory tokenBs) external view returns (uint totalA, uint totalB, uint[] memory virtualAs, uint[] memory virtualBs);
  function getReserves(address[] memory tokenAs, address[] memory tokenBs) external view returns (uint totalA, uint totalB, uint[] memory reserveAs, uint[] memory reserveBs);

  function mint(address to, address[] memory tokenXs, 
    address[] memory tokenYs, 
    uint[] memory amountXs,
    uint[] memory amountYs) external returns (uint liquidity);
  function swap(address[] memory tokensIn, address[] memory tokensOut, uint[] memory amountsIn, uint[] calldata amountsXOut, uint[] calldata amountsYOut, address to) external;

  function getGroupX() external view returns (address[] memory tokenXs);
  function getGroupY() external view returns (address[] memory tokenYs);
  function groupX(uint) external view returns (address tokenX);
  function groupY(uint) external view returns (address tokenY);
  function groupXLength() external view returns (uint);
  function groupYLength() external view returns (uint);

}

