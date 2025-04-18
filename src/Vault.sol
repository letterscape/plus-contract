pragma solidity ^0.8.20;

import "./Swaplus.sol";
import "./PoolFactory.sol";

contract Vault {

    Swaplus swaplus;
    IERC20 token;
    PoolFactory poolFactory;

    // 用于记录每个地址的余额
    mapping(address account => uint256) private _balances;
    mapping(address account => address[]) private _pools;
    
    // 事件声明
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor(address _swaplus, address _token, address _poolFactory) {
        swaplus = Swaplus(_swaplus);
        token = IERC20(_token);
        poolFactory = PoolFactory(_poolFactory);
    }
    
    /*
      存款功能，允许用户向金库中存入资金
     */
    function deposit(uint256 amount) public returns (bool) {
        address sender = msg.sender;
        _balances[sender] += amount;
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (success) {
            emit Deposit(sender, amount);
        }
        return success;
    }
    
    /**
     取款功能，允许用户从金库中取出资金
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than zero");
        require(_balances[msg.sender] >= amount, "Insufficient balance");
        
        _balances[msg.sender] -= amount;
        
        // 转账给用户
        token.transfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * 查询用户余额
     */
    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }

    function addLiquidity(
      address[] memory groupA, 
      address[] memory groupB, 
      uint[] memory amountsADesired,
      uint[] memory amountsBDesired,
      uint[] memory amountsAMin,
      uint[] memory amountsBMin,
      address to,
      uint deadline
    ) external {
        address pool = PoolFactory(poolFactory).getPools(groupA, groupB);
        approveBatch(groupA, pool);
        approveBatch(groupB, pool);
        swaplus.addLiquidity(groupA, groupB, amountsADesired, amountsBDesired, amountsAMin, amountsBMin, to, deadline);
        // todo 去重
        _pools[msg.sender].push(pool);
    }   

    function poolsOf(address account) public view returns (address[] memory) {
        return _pools[account];
    }

    function approveBatch(address[] memory tokens, address spender) private {
        for (uint i = 0; i < tokens.length; i++) {
            IERC20(token).approve(spender, type(uint).max);
            IERC20(token).approve(address(swaplus), type(uint).max);
        } 
    }
}
