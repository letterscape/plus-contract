// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/IPoolFactory.sol";
import "./libraries/SwaplusV1Library.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ISwapPool.sol";

contract Swaplus {

  address public immutable factory;

  modifier ensure(uint deadline) {
    require(deadline >= block.timestamp, 'SwaplusV 1: EXPIRED');
    _;
  }

  constructor(address _factory) {
    factory = _factory;
  }

  function _addLiquidity(
    address[] memory groupA, 
    address[] memory groupB, 
    uint[] memory amountsADesired,
    uint[] memory amountsBDesired,
    uint[] memory amountsAMin,
    uint[] memory amountsBMin
  ) private returns (uint[] memory amountsA, uint[] memory amountsB) {

    // require(groupA.length == amountsADesired.length &&  amountsADesired.length == amountsAMin.length, 'SwaplusV1: INCONSISTENT_LIQUIDITY');
    // require(groupB.length == amountsBDesired.length &&  amountsBDesired.length == amountsBMin.length, 'SwaplusV1: INCONSISTENT_LIQUIDITY');
  
    if (IPoolFactory(factory).getPools(groupA, groupB) == address(0)) {
      IPoolFactory(factory).createPool(groupA, groupB);
    }
    (uint reserveA, uint reserveB) = SwaplusV1Library.getVirtualReserveSum(factory, groupA, groupB);
    
    bool isOptimal = (amountsADesired.length == 0 && amountsBDesired.length == 0 && amountsAMin.length == 0 && amountsBMin.length == 0) ? false : true;
    if ((reserveA == 0 && reserveB == 0) || !isOptimal) {
      (amountsA, amountsB) = (amountsADesired, amountsBDesired);
    } else {
      (amountsA, amountsB) = calAmounts(groupA, groupB, amountsADesired,amountsBDesired, amountsAMin, amountsBMin);
    }
  }

  function calAmounts(
      address[] memory groupA, 
      address[] memory groupB, 
      uint[] memory amountsADesired,
      uint[] memory amountsBDesired,
      uint[] memory amountsAMin,
      uint[] memory amountsBMin) internal view returns (uint[] memory amountsA, uint[] memory amountsB) {
    
    (, , uint[] memory reservesA, uint[] memory reservesB) = SwaplusV1Library.getVirtualReserves(factory, groupA, groupB, groupA, groupB);
    amountsA = new uint[](amountsADesired.length);
    amountsB = new uint[](amountsBDesired.length);
    bool isQuoteFailed = false;
    // 根据A组的币种数额计算出所有币种的最佳数额
    for (uint i = 0; i < amountsADesired.length; i++) {
      // 计算同组其他币种的最佳数额
      for (uint j = 0; j < amountsADesired.length; j++) {
        if (amountsA[j] > 0) continue; // 已经计算过
        if (amountsADesired[j] == 0) continue; // 为0时无需计算
        if (i != j) {
          uint amountAjOptimal = SwaplusV1Library.quote(amountsADesired[i], reservesA[i], reservesA[j]);
          if (amountAjOptimal <= amountsADesired[j]) {
            require(amountAjOptimal >= amountsAMin[j], 'SwaplusV1: INSUFFICIENT_A_AMOUNT');
            amountsA[j] = amountAjOptimal;
          } else {
            isQuoteFailed = true;
            break;
          }
        }
      }
      // 如果有一个币种没找到其他币种的最佳数额，则换其他币种
      if (isQuoteFailed) continue;
      // 计算不同组币种的最佳金额
      for (uint j = 0; j < amountsBDesired.length; j++) {
        if (amountsB[j] > 0) continue; // 已经计算过
        if (amountsBDesired[j] == 0) continue; // 为0时无需计算
        uint amountBjOptimal = SwaplusV1Library.quote(amountsADesired[i], reservesA[i], reservesB[j]);
        if (amountBjOptimal <= amountsBDesired[j]) {
          require(amountBjOptimal >= amountsBMin[j], 'SwaplusV1: INSUFFICIENT_B_AMOUNT');
          amountsB[j] = amountBjOptimal;
        } else {
          isQuoteFailed = true;
          break;
        }
      }
      if (isQuoteFailed) continue;
      amountsA[i] = amountsADesired[i];
    }
    if (isQuoteFailed) {
      // 根据B组的币种数额计算出所有币种的最佳数额
      for (uint i = 0; i < amountsBDesired.length; i++) {
        // 计算同组其他币种的最佳数额
        for (uint j = 0; j < amountsBDesired.length; j++) {
          if (i != j) {
            uint amountBjOptimal = SwaplusV1Library.quote(amountsBDesired[i], reservesB[i], reservesB[j]);
            assert(amountBjOptimal <= amountsBDesired[j]);
            require(amountBjOptimal >= amountsBMin[j], 'SwaplusV1: INSUFFICIENT_B_AMOUNT');
            amountsB[j] = amountBjOptimal;
          }
        }
        // 如果有一个币种没找到其他币种的最佳数额，则换其他币种
        // 计算不同组币种的最佳金额
        for (uint j = 0; j < amountsADesired.length; j++) {
          uint amountAjOptimal = SwaplusV1Library.quote(amountsBDesired[i], reservesB[i], reservesA[j]);
          assert(amountAjOptimal <= amountsADesired[j]);
          require(amountAjOptimal >= amountsAMin[j], 'SwaplusV1: INSUFFICIENT_A_AMOUNT');
          amountsA[j] = amountAjOptimal;
        }
        amountsB[i] = amountsBDesired[i];
      }
    }
  }

  // todo 添加单一流动性

  function addLiquidity(
      address[] memory groupA, 
      address[] memory groupB, 
      uint[] memory amountsADesired,
      uint[] memory amountsBDesired,
      uint[] memory amountsAMin,
      uint[] memory amountsBMin,
      address to,
      uint deadline
  ) external ensure(deadline) returns (uint[] memory amountsA, uint[] memory amountsB, uint liquidity) {
    
    (amountsA, amountsB) = _addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin);
    address pool = SwaplusV1Library.getPool(factory, groupA, groupB);
    
    // 将token转移到流动性池中
    transfromBatch(groupA, msg.sender, pool, amountsA);
    transfromBatch(groupB, msg.sender, pool, amountsB);

    // 分发LP-token
    liquidity = ISwapPool(pool).mint(to, groupA, groupB, amountsA, amountsB);
  }

  function removeLiquidity() external {

  }

  function _swap(
    address pool,
    address[] memory groupIn, 
    address[] memory groupOut,
    address[] memory tokensIn,
    address[] memory tokensOut,
    uint[] memory amountsIn,
    uint[] memory amountsOut,
    address to
  ) private {
    (bytes32 bytesA, , ,) = SwaplusV1Library.sortTokens(groupIn, groupOut);
    (uint[] memory amountsXOut, uint[] memory amountsYOut) = 
        bytesA == keccak256(abi.encode(groupIn)) ? (new uint[](0), amountsOut) : (amountsOut, new uint[](0));
    ISwapPool(pool).swap(tokensIn, tokensOut, amountsIn, amountsXOut, amountsYOut, to);
  }

  function swapExactTokensForTokens(
    address[] memory groupIn, 
    address[] memory groupOut,
    address[] memory tokensIn,
    address[] memory tokensOut,
    uint[] memory amountsIn,
    uint[] memory amountOutsMin,
    address to,
    uint deadline
  ) external ensure(deadline) returns (uint[] memory amountsOut) {
    
    require(tokensIn.length == amountsIn.length && tokensOut.length == amountOutsMin.length, 'SwaplusV1: INCONSISTENT_SWAP');

    amountsOut = SwaplusV1Library.getAmountsOut(factory, groupIn, groupOut, tokensIn, tokensOut, amountsIn);
    // 检查是否满足换出的最小数额
    for (uint i = 0; i < tokensOut.length; i++) {
      require(amountsOut[i] >= amountOutsMin[i], 'SwaplusV1: INSUFFICIENT_OUTPUT_AMOUNT');
    }

    address pool = SwaplusV1Library.getPool(factory, groupIn, groupOut);
    for (uint i = 0; i < tokensIn.length; i++) {
      safeTransferFrom(tokensIn[i], msg.sender, pool, amountsIn[i]);
    }

    _swap(pool, groupIn, groupOut, tokensIn, tokensOut, amountsIn, amountsOut, to);
  }

    function swapTokensForExactTokens(
      address[] memory groupIn, 
      address[] memory groupOut,
      address[] memory tokensIn,
      address[] memory tokensOut,
      uint[] memory amountsOut,
      uint[] memory amountInMax,
      address to,
      uint deadline
    ) external ensure(deadline) returns (uint[] memory amountsIn) {
      require(tokensIn.length == amountInMax.length && tokensOut.length == amountsOut.length, 'SwaplusV1: INCONSISTENT_SWAP');

      amountsIn = SwaplusV1Library.getAmountsIn(factory, groupIn, groupOut, tokensIn, tokensOut, amountsOut);
      // 检查是否满足投入的最大数额
      for (uint i = 0; i < tokensOut.length; i++) {
        require(amountsIn[i] <= amountInMax[i], 'SwaplusV1: INSUFFICIENT_OUTPUT_AMOUNT');
      }

      address pool = SwaplusV1Library.getPool(factory, groupIn, groupOut);
      for (uint i = 0; i < tokensIn.length; i++) {
        safeTransferFrom(tokensIn[i], msg.sender, pool, amountsIn[i]);
      }

      _swap(pool, groupIn, groupOut, tokensIn, tokensOut, amountsIn, amountsOut, to);
    }

    function transfromBatch(address[] memory group, address from, address to, uint[] memory amounts) internal {
      for (uint i = 0; i < group.length; i++) {
        safeTransferFrom(group[i], from, to, amounts[i]);
      }
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // (bool success, bytes memory data) =
        //     token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        // require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
        IERC20(token).transferFrom(from, to, value);
    }
}