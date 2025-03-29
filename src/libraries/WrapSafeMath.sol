pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";

library WrapSafeMath {
  using Math for uint;
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }

    function ceilDiv(uint x, uint y) internal pure returns (uint z) {
        z = x.ceilDiv(y);
    }

    function sqrt(uint a) internal pure returns (uint) {
        return sqrt(a);
    }
}