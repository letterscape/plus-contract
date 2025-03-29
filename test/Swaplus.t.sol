pragma solidity >=0.8.0 <0.9.0;

import { Test, console } from "forge-std/Test.sol";
import "../src/PoolFactory.sol";
import "../src/SwapPool.sol";
import "../src/Swaplus.sol";
import "../src/CustomToken.sol";
import "../src/libraries/WrapSafeMath.sol";

contract SwaplusTest is Test {
  using WrapSafeMath for uint;

  PoolFactory public factory;
  Swaplus public app;

  address[] tokens;
  mapping(address => uint) oracle;

  address[] groupA;
  address[] groupB;
  uint[] amountsADesired;
  uint[] amountsBDesired;
  uint[] amountsAMin;
  uint[] amountsBMin;

  function setUp() public {
    factory = new PoolFactory();
    app = new Swaplus(address(factory));
    createTokens();

  }

  function test_allTokens() public {
    address[] memory createdPools = createPools();
    address[] memory pools = test_getAllPools();
    for (uint256 i = 0; i < 10; i++) {
      assertEq(createdPools[i], pools[i]);

      SwapPool pool = SwapPool(pools[i]);
      address[] memory tokenXs = pool.getGroupX();
      uint256 lenX = pool.groupXLength();
      for (uint j = 0; j < lenX; j++) {
        address tokenX = tokenXs[j];
        console.log('pool%s-tokenX:%s', i, tokenX);
      }

      uint256 lenY = pool.groupYLength();
      for (uint j = 0; j < lenY; j++) {
        address tokenY = pool.groupX(j);
        console.log('pool%s-tokenY:%s', i, tokenY);
      }
      console.log('---');
    }

  }

  function createPools() public returns (address[] memory pools){
    pools = new address[](10);
    for (uint256 i = 0; i < 10; i++) {
      address[] memory groupX = new address[](3);
      address[] memory groupY = new address[](3);
      uint256 j = i * 6;
      groupX[0] = vm.addr(1 + j);
      groupX[1] = vm.addr(2 + j);
      groupX[2] = vm.addr(3 + j);
      groupY[0] = vm.addr(4 + j);
      groupY[1] = vm.addr(5 + j);
      groupY[2] = vm.addr(6 + j);
      pools[i] = createPool(groupX, groupY);
    }
    
  }

  function createPool(address[] memory groupX, address[] memory groupY) public returns (address pool) {
    pool = factory.createPool(groupX, groupY);
    console.log('pool %s created', pool);
    return pool;
  }

  function test_getAllPools() public returns (address[] memory pools) {

    uint256 len = factory.allPoolsLength();
    pools = new address[](len);
    for (uint256 i = 0; i < len; i++) {
      address pool = factory.allPools(i);
      console.log('pool%s: %s', i, pool);
      pools[i] = pool;
    }
    return pools;
  }

  function reset() public {
    groupA = new address[](0);
    groupB = new address[](0);
    amountsADesired = new uint[](0);
    amountsBDesired = new uint[](0);
    amountsAMin = new uint[](0);
    amountsBMin = new uint[](0);
  }

  function createTokens() public {
    IERC20 eth = new CustomToken("ETH", "ETH");
    tokens.push(address(eth));
    oracle[address(eth)] = 1000;
    // oracle[address(eth)] = 23409000;
    console.log('eth created:', address(eth));

    IERC20 bnb = new CustomToken("BNB", "BNB");
    tokens.push(address(bnb));
    oracle[address(bnb)] = 2000;
    // oracle[address(bnb)] = 6123500;
    console.log('bnb created:', address(bnb));

    IERC20 sol = new CustomToken("SOL", "SOL");
    tokens.push(address(sol));
    oracle[address(sol)] = 3000;
    // oracle[address(sol)] = 1372100;
    console.log('sol created:', address(sol));

    IERC20 usdt = new CustomToken("USDT", "USDT");
    tokens.push(address(usdt));
    oracle[address(usdt)] = 500;
    // oracle[address(usdt)] = 10000;
    console.log('usdt created:', address(usdt));

    IERC20 xrp = new CustomToken("XRP", "XRP");
    tokens.push(address(xrp));
    oracle[address(xrp)] = 1000;
    // oracle[address(xrp)] = 21926;
    console.log('xrp created:', address(xrp));

    IERC20 ltc = new CustomToken("LTC", "LTC");
    tokens.push(address(ltc));
    oracle[address(ltc)] = 1500;
    // oracle[address(ltc)] = 1241700;
    console.log('ltc created:', address(ltc));

    IERC20 sui = new CustomToken("SUI", "SUI");
    tokens.push(address(sui));
    oracle[address(sui)] = 2000;
    // oracle[address(sui)] = 28856;
    console.log('sui created:', address(sui));
  }

  function test_createLiquidity_2tokens() public {
    reset();
    createLiquidity_2();
  }

  function test_swapExactTokensForTokens_2tokens_in2Liquidity() public {
    reset();
    createLiquidity_2();
    console.log('pool created, current pool liquidity:');
    printK();
    swapExactTokensForTokens_2tokens();
    console.log('ExactTokensForTokens swapped, current pool liquidity:');
    printK();
  }

  function swapExactTokensForTokens_2tokens() public {

    address swaper = makeAddr("swaper");
    
    vm.startPrank(swaper);
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken(tokens[i]).mint(swaper, 10 ** 18);
      CustomToken(tokens[i]).approve(address(app), type(uint).max);
      // console.log('%s balance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).balanceOf(provider));
      // console.log('%s allowance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).allowance(provider, address(app)));
    }

    address[] memory tokensIn = new address[](1);
    address[] memory tokensOut = new address[](1);
    uint[] memory amountsIn = new uint[](1);
    uint[] memory amountOutsMin = new uint[](1);
    tokensIn[0] = groupA[0];
    tokensOut[0] = groupB[0];
    amountsIn[0] = 600;
    amountOutsMin[0] = 1;
    uint32 deadline =  uint32(block.timestamp + 100000);
    uint[] memory amountsOut = app.swapExactTokensForTokens(groupA, groupB, tokensIn, tokensOut, amountsIn, amountOutsMin, swaper, deadline);
    assertEq(amountsOut[0] >= amountOutsMin[0], true);

    vm.stopPrank();
  }

  function test_swapTokensForExactTokens_2tokens_in2Liquidity() public {
    reset();
    createLiquidity_2();
    console.log('pool created, current pool liquidity:');
    printK();
    swapTokensForExactTokens_2tokens();
    console.log('swapped, current pool liquidity:');
    printK();
  }

  function swapTokensForExactTokens_2tokens() public {

    address swaper = makeAddr("swaper");
    
    vm.startPrank(swaper);
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken(tokens[i]).mint(swaper, 10 ** 18);
      IERC20(tokens[i]).approve(address(app), type(uint).max);
      // console.log('%s balance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).balanceOf(provider));
      // console.log('%s allowance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).allowance(provider, address(app)));
    }

    address[] memory tokensIn = new address[](1);
    address[] memory tokensOut = new address[](1);
    uint[] memory amountsOut = new uint[](1);
    uint[] memory amountInMax = new uint[](1);
    tokensIn[0] = groupA[0];
    tokensOut[0] = groupB[0];
    amountsOut[0] = 100;
    amountInMax[0] = amountsOut[0] * oracle[groupA[0]] / oracle[groupB[0]] + type(uint128).max;
    uint32 deadline =  uint32(block.timestamp + 100000);
    uint[] memory amountsIn = app.swapTokensForExactTokens(groupA, groupB, tokensIn, tokensOut, amountsOut, amountInMax, swaper, deadline);
    assertEq(amountInMax[0] >= amountsIn[0], true);

    
    vm.stopPrank();
  }

  function createLiquidity_2() public {
    address to = vm.addr(1);
    uint32 deadline =  uint32(block.timestamp + 100000);
    address provider = makeAddr("provider");
    
    vm.startPrank(provider);
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken(tokens[i]).mint(provider, 10 ** 32);
      CustomToken(tokens[i]).approve(address(app), type(uint).max);
      // console.log('%s balance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).balanceOf(provider));
      // console.log('%s allowance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).allowance(provider, address(app)));
    }

    uint base = 10 ** 5;
    groupA.push(tokens[0]);
    groupB.push(tokens[3]);
    amountsADesired.push(base);
    amountsBDesired.push(base * oracle[groupA[0]] / oracle[groupB[0]]);
    amountsAMin.push(oracle[groupA[0]] - 1);
    amountsBMin.push(oracle[groupB[0]] - 1);
    (, , uint liquidity) = app.addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin, to, deadline);
    address pool = getPool(groupA, groupB);
    uint expectedLiquidity = Math.sqrt(amountsADesired[0].mul(amountsBDesired[0])).sub(SwapPool(pool).MINIMUM_LIQUIDITY());
    assertEq(liquidity, expectedLiquidity);
    
    vm.stopPrank();
  }

  function test_addLiquidity_Ntokens() public {
    reset();
    createLiquidity_N();
    console.log('pool created, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
  }

  // 添加单边流动性测试
  function test_addLiquidity_single() public {
    reset();
    createLiquidity_N();
    console.log('pool created, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    printK();
    address provider = makeAddr("provider");
    vm.startPrank(provider);
    address to = vm.addr(1);
    uint32 deadline =  uint32(block.timestamp + 100000);
    amountsADesired = new uint[](groupA.length);
    amountsADesired[0] = 1000;
    amountsBDesired = new uint[](groupB.length);
    amountsAMin = new uint[](groupA.length);
    amountsBMin = new uint[](groupB.length);
    app.addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin, to, deadline);
    printK();
    vm.stopPrank();
  }

  function createLiquidity_N() public {
    address to = vm.addr(1);
    uint32 deadline =  uint32(block.timestamp + 100000);
    address provider = makeAddr("provider");
    
    vm.startPrank(provider);
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken(tokens[i]).mint(provider, 10 ** 32);
      CustomToken(tokens[i]).approve(address(app), type(uint).max);
      // console.log('%s balance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).balanceOf(provider));
      // console.log('%s allowance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).allowance(provider, address(app)));
    }

    for (uint i = 0; i < tokens.length; i++) {
      if (i < tokens.length / 2) {
        groupA.push(tokens[i]);      
      } else {
        groupB.push(tokens[i]);
      }
    }
    uint base = 10 ** 5;
    uint reservePlusA = 0;
    uint reservePlusB = 0;
    for (uint i = 0; i < groupA.length; i++) {
      // uint num = base * oracle[groupA[i]] / oracle[groupA[0]];
      uint num = oracle[groupA[i]];
      reservePlusA += num;
      amountsADesired.push(num);
      amountsAMin.push(oracle[groupA[i]] - 1);
    }
    for (uint i = 0; i < groupB.length; i++) {
      // uint num = base * oracle[groupA[i]] / oracle[groupB[0]];
      uint num = oracle[groupB[i]];
      reservePlusB += num;
      amountsBDesired.push(num);
      amountsBMin.push(oracle[groupB[i]] - 1);
    }
    (, , uint liquidity) = app.addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin, to, deadline);
    address pool = getPool(groupA, groupB);
    uint expectedLiquidity = Math.sqrt(reservePlusA.mul(reservePlusB)).sub(SwapPool(pool).MINIMUM_LIQUIDITY());
    assertEq(liquidity, expectedLiquidity);
    
    vm.stopPrank();
  }

  function test_swapTokensForExactTokens_2tokens_inNLiquidity() public {
    reset();
    createLiquidity_N();
    console.log('pool created, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    printK();
    swapTokensForExactTokens_2tokens();
    console.log('TokensForExactTokens_2tokens_inNLiquidity swapped, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    printK();
  }

  function test_swapExactTokensForTokens_2tokens_inNLiquidity() public {
    reset();
    createLiquidity_N();
    console.log('pool created, current pool liquidity:');
    printK();
    swapExactTokensForTokens_2tokens();
    console.log('ExactTokensForTokens_2tokens_inNLiquidity swapped, current pool liquidity:');
    printK();
  }

  function test_swapExactTokensForTokens_Ntokens_inNLiquidity() public {
    reset();
    createLiquidity_N();
    console.log('pool created, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    console.log('pool created, current Reserves:');
    SwapPool(getPool(groupA, groupB)).getReserves(groupA, groupB);
    printK();
    swapExactTokensForTokens_Ntokens();
    console.log('ExactTokensForTokens_Ntokens_inNLiquidity swapped, current pool liquidity:');
    SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    console.log('ExactTokensForTokens_Ntokens_inNLiquidity swapped, current Reserves:');
    SwapPool(getPool(groupA, groupB)).getReserves(groupA, groupB);
    printK();
  }

  function swapExactTokensForTokens_Ntokens() public {

    address swaper = makeAddr("swaper");
    
    vm.startPrank(swaper);
    for (uint i = 0; i < tokens.length; i++) {
      CustomToken(tokens[i]).mint(swaper, 10 ** 18);
      CustomToken(tokens[i]).approve(address(app), type(uint).max);
      // console.log('%s balance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).balanceOf(provider));
      // console.log('%s allowance:', CustomToken(tokens[i]).name(), CustomToken(tokens[0]).allowance(provider, address(app)));
    }
    
    address[] memory tokensIn = new address[](2);
    address[] memory tokensOut = new address[](2);
    uint[] memory amountsIn = new uint[](2);
    uint[] memory amountOutsMin = new uint[](2);
    tokensIn[0] = groupA[0];
    tokensIn[1] = groupA[1];
    tokensOut[0] = groupB[0];
    tokensOut[1] = groupB[1];
    // tokensOut[2] = groupB[2];
    amountsIn[0] = 250;
    amountsIn[1] = 350;
    amountOutsMin[0] = 1;
    amountOutsMin[1] = 2;
    uint32 deadline =  uint32(block.timestamp + 100000);
    uint[] memory amountsOut = app.swapExactTokensForTokens(groupA, groupB, tokensIn, tokensOut, amountsIn, amountOutsMin, swaper, deadline);
    assertEq(amountsOut[0] >= amountOutsMin[0], true);
    
    vm.stopPrank();
  }

  function getPool(address[] memory _groupA, address[] memory _groupB) public view returns (address pool) {
    pool = factory.pools(keccak256(abi.encode(_groupA)), keccak256(abi.encode(_groupB)));
  }

  function printK() public {
    (, , uint[] memory virtualAs, uint[] memory virtualBs) = SwapPool(getPool(groupA, groupB)).getVirtuals(groupA, groupB);
    uint k = getK(virtualAs, virtualBs);
    console.log('current K:', k);
  }

  function getK(uint[] memory x, uint[] memory y) public returns (uint k) {
    uint sumX = 0;
    uint sumY = 0;
    for (uint i = 0; i < x.length; i++) {
      sumX += x[i];
    }
    for (uint i = 0; i < y.length; i++) {
      sumY += y[i];
    }
    k = sumX.mul(sumY);
  }
}