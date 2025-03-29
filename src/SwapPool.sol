// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/WrapSafeMath.sol";
import "./interfaces/ISwapPool.sol";
import { console } from "forge-std/Test.sol";

contract SwapPool is ISwapPool, ERC20Permit {
  using WrapSafeMath for uint;

  bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

  uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

  uint public constant ZOOM_FACTOR = 10 ** 32;
  address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  address public factory;

  address[] public groupX;
  address[] public groupY;

  // group中每个token的储备金
  mapping(address => uint) reserveTable;
  // group中每个token的比例
  mapping(address => uint) virtualTable;

  // 通过piceFeedPair字符串查询喂价系统
  // 例：eth-address => "ETH/USD"
  mapping(address => string) priceFeedPairMapping;

  constructor() ERC20("Swaplus V1", "SP") ERC20Permit("SwaplusV1") {
    factory = msg.sender;
  }

  function initialize(
    address[] calldata _groupX,
    address[] calldata _groupY
  ) external {
    require(msg.sender == factory, "SwaplusV1: FORBIDDEN"); // sufficient check
    groupX = _groupX;
    groupY = _groupY;
  }

  function getVirtualSum() public view override returns (uint sumX, uint sumY) {
    for (uint i = 0; i < groupX.length; i++) {
      sumX += virtualTable[groupX[i]];
    }
    for (uint i = 0; i < groupY.length; i++) {
      sumY += virtualTable[groupY[i]];
    }
  }  

  function getVirtuals(address[] memory tokenAs, address[] memory tokenBs) public view override returns (uint totalA, uint totalB, uint[] memory virtualAs, uint[] memory virtualBs) {
    virtualAs = new uint[](tokenAs.length);
    virtualBs = new uint[](tokenBs.length);
    for (uint i = 0; i < tokenAs.length; i++) {
      virtualAs[i] = virtualTable[tokenAs[i]];
      totalA += virtualTable[tokenAs[i]];
    }
    for (uint i = 0; i < tokenBs.length; i++) {
      virtualBs[i] = virtualTable[tokenBs[i]];
      totalB += virtualTable[tokenBs[i]];
    }
  }

  function getReserves(address[] memory tokenAs, address[] memory tokenBs) public view override returns (uint totalA, uint totalB, uint[] memory reserveAs, uint[] memory reserveBs) {
    reserveAs = new uint[](tokenAs.length);
    reserveBs = new uint[](tokenBs.length);
    for (uint i = 0; i < tokenAs.length; i++) {
      reserveAs[i] = reserveTable[tokenAs[i]];
      totalA += reserveTable[tokenAs[i]];
    }
    for (uint i = 0; i < tokenBs.length; i++) {
      reserveBs[i] = reserveTable[tokenBs[i]];
      totalB += reserveTable[tokenBs[i]];
    }
  }

  // to地址用来接收LP-token
  function mint(
    address to, 
    address[] memory tokenXs, 
    address[] memory tokenYs, 
    uint[] memory amountXs,
    uint[] memory amountYs
  ) external override returns (uint liquidity) {
    // todo mint fee

    uint totalSupplyLp = totalSupply();
    if (totalSupplyLp == 0) {
      // create liquidity
      // 资金池初始化流动性数量应该是Sum(投入的x)*Sum(投入的y)的平方根，这里使用资金池的各个Token余额之和减去储备金总额reserve的差值，来算出投入的量
      liquidity = Math.sqrt(sum(amountXs).mul(sum(amountYs))).sub(MINIMUM_LIQUIDITY);
      // 锁住MINIMUM_LIQUIDITY作为创建流动性的成本
      _mint(BURN_ADDRESS, MINIMUM_LIQUIDITY);
      initVirtualTable(tokenXs, tokenYs, amountXs, amountYs);
    } else {
      (uint numeratorX, uint denominatorX, uint numeratorY, uint denominatorY) = reBalance(amountXs, amountYs, true, true);
      // add liquidity
      liquidity = Math.min(totalSupplyLp.mul(numeratorX) / denominatorX, totalSupplyLp.mul(numeratorY) / denominatorY);
    }
    require(liquidity > 0, 'SwaplusV1: INSUFFICIENT_LIQUIDITY_MINTED');
    _mint(to, liquidity);
    _updateReserveTable(tokenXs, tokenYs);
    emit Mint(block.timestamp, msg.sender, liquidity, tokenXs, tokenYs, amountXs, amountYs);
  }

  // 此处只处理转出
  function swap(
    address[] memory tokensIn,
    address[] memory tokensOut,
    uint[] memory amountsIn,
    uint[] memory amountsXOut,
    uint[] memory amountsYOut,
    address to) external override {
    
    uint outLen = tokensOut.length;
    require(outLen == amountsXOut.length || outLen == amountsYOut.length, 'SwaplusV1 INCONSISTENT_OUTPUT');
    
    uint totalXOut = 0;
    uint totalYOut = 0;

    for (uint i = 0; i < outLen; i++) {
      if (amountsXOut.length > 0) {
        require(amountsXOut[i] > 0, 'SwaplusV1 INSUFFICIENT_OUTPUT_AMOUNT');
        totalXOut += amountsXOut[i];
      } else {
        require(amountsYOut[i] > 0, 'SwaplusV1 INSUFFICIENT_OUTPUT_AMOUNT');
        totalYOut += amountsYOut[i];
      }
    }

    if (totalXOut > 0) {
      reBalance(amountsXOut, amountsIn, false, true);
      transferBatch(tokensOut, to, amountsXOut);
    } else if (totalYOut > 0) {
      reBalance(amountsIn, amountsYOut, true, false);
      transferBatch(tokensOut, to, amountsYOut);
    }
    
    _updateReserveTable(tokensIn, tokensOut);
    emit Swap(block.timestamp, msg.sender, tokensOut, amountsXOut, amountsYOut, to);
  }

  function transferBatch(address[] memory tokens, address to, uint[] memory amounts) private {
    for (uint i = 0; i < tokens.length; i++) {
      require(amounts[i] <= reserveTable[tokens[i]], 'SwaplusV1 INSUFFICIENT_LIQUIDITY');
      _safeTransfer(tokens[i], to, amounts[i]);
    }
  }

  function _updateReserveTable(address[] memory tokens) private {
    uint[] memory balances = getBalances(tokens);
    for (uint i = 0; i < balances.length; i++) {
      require(balances[i] <= type(uint256).max, 'SwaplusV1: BALANCE_OVERFLOW');
      reserveTable[tokens[i]] = balances[i];
    }
    emit Sync1(block.timestamp, tokens, balances);
  }

  function _updateReserveTable(address[] memory tokenXs, address[] memory tokenYs) private {
    (uint[] memory balanceXs, uint[] memory balanceYs) = getBalances(tokenXs, tokenYs);

    for (uint i = 0; i < balanceXs.length; i++) {
      require(balanceXs[i] <= type(uint256).max, 'SwaplusV1: BALANCE_OVERFLOW');
      reserveTable[tokenXs[i]] = balanceXs[i];
    }
    for (uint i = 0; i < balanceYs.length; i++) {
      require(balanceYs[i] <= type(uint256).max, 'SwaplusV1: BALANCE_OVERFLOW');
      reserveTable[tokenYs[i]] = balanceYs[i];
    }
    emit Sync2(block.timestamp, tokenXs, tokenYs, balanceXs, balanceYs);
  }

  // 有些token不会返回success的结果
  function _safeTransfer(address token, address to, uint value) private {
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
  }

  function getBalances(address[] memory tokenXs, address[] memory tokenYs) public view returns (uint[] memory balanceXs, uint[] memory balanceYs) {
    balanceXs = getBalances(tokenXs);
    balanceYs = getBalances(tokenYs);
  }

  function getBalances(address[] memory tokens) public view returns (uint[] memory balances) {
    uint len = tokens.length;
    balances = new uint[](len);
    for (uint i = 0; i < len; i++) {
      balances[i] = IERC20(tokens[i]).balanceOf(address(this));
    }
  }

  function setPriceFeedPairMapping(address token) private {
    priceFeedPairMapping[token] = string.concat(ERC20(token).name(), "/USD");
  }

  function burn(address to) internal {

  }

  function initVirtualTable(
    address[] memory _groupX, 
    address[] memory _groupY, 
    uint[] memory amountXs,
    uint[] memory amountYs
  ) private {
    createVirtualTable(_groupX, amountXs);
    createVirtualTable(_groupY, amountYs);
  }

  function createVirtualTable(address[] memory group, uint[] memory amounts) private {
    for (uint i = 0; i < group.length; i++) {
      virtualTable[group[i]] = amounts[i];
    }
  }

  function reBalance(
    uint[] memory amountXs,
    uint[] memory amountYs,
    bool isPositiveX,
    bool isPositiveY
  ) private returns (uint numeratorX, uint denominatorX, uint numeratorY, uint denominatorY) {
    (denominatorX, denominatorY) = getVirtualSum();
    numeratorX = sum(amountXs);
    numeratorY = sum(amountYs);
    require(numeratorX > 0 || numeratorY > 0, 'SwaplusV1: Zero amount');
    
    // 处理添加单边流动性
    if (numeratorX == 0 || numeratorY == 0) {
      (numeratorX, numeratorY) = numeratorBalancing(numeratorX, numeratorY, denominatorX, denominatorY);
    } 

    balancing(groupX, numeratorX, denominatorX, isPositiveX);     
    balancing(groupY, numeratorY, denominatorY, isPositiveY);
  }

  function numeratorBalancing(
    uint _numeratorX, 
    uint _numeratorY,
    uint denominatorX, 
    uint denominatorY
  ) private returns (uint numeratorX, uint numeratorY) {
    if (_numeratorX == 0) {
      numeratorX = _numeratorY.mul(denominatorX).ceilDiv(denominatorX + denominatorY);
      numeratorY = _numeratorY - numeratorX;
    } else if (_numeratorY == 0) {
      numeratorY = _numeratorX.mul(denominatorY).ceilDiv(denominatorX + denominatorY);
      numeratorX = _numeratorX - numeratorY;
    }
  }

  function balancing(
    address[] memory group, 
    uint amounts, 
    uint total,
    bool isPositive
  ) private {
    for (uint i = 0; i < group.length; i++) {
      uint tmp = virtualTable[group[i]];
      if (isPositive) {
        virtualTable[group[i]] += amounts.mul(tmp).ceilDiv(total);
      } else {
        require(virtualTable[group[i]] >= amounts.mul(tmp).ceilDiv(total), 'SwaplusV1: BALANCING_FAILED');
        virtualTable[group[i]] -= amounts.mul(tmp).ceilDiv(total);
      }
    }
  }

  function sum(uint[] memory amounts) internal pure returns (uint res) {
    for (uint i = 0; i < amounts.length; i++) {
      res = res.add(amounts[i]);
    }
  }

  function getGroupX() external view returns (address[] memory tokenXs) {
    return groupX;
  }

  function getGroupY() external view returns (address[] memory tokenYs) {
    return groupY;
  }

  function groupXLength() external view returns (uint) {
    return groupX.length;
  }

  function groupYLength() external view returns (uint) {
    return groupY.length;
  }

  // function reBalance() private {
  //   uint groupXLen = groupX.length;
  //   uint groupYLen = groupY.length;
  //   uint weightFactorOfX = 0;
  //   uint weightFactorOfY = 0;
  //   uint[] memory balancesX;
  //   uint[] memory balancesY;

  //   for (uint i = 0; i < groupXLen; i++) {
  //     uint balance = IERC20(groupX[i]).balanceOf(address(this));
  //     balancesX[i] = balance;
  //     weightFactorOfY += ZOOM_FACTOR / balance;
  //   }
  //   for (uint i = 0; i < groupYLen; i++) {
  //     uint balance = IERC20(groupY[i]).balanceOf(address(this));
  //     balancesY[i] = balance;
  //     weightFactorOfX += ZOOM_FACTOR / balance;
  //   }

  //   for (uint i = 0; i < groupXLen; i++) {
  //     uint balance = IERC20(groupX[i]).balanceOf(address(this));
  //   }
  // }
}
