// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/Safemathuint2.sol";

contract Globals is DSAuth {
    using SafeMathUint for uint256;

    // State variables
    mapping(address => uint256) public _shares;
    mapping(address => uint256) public _balances;
    uint256 public _totalDeposits;

    // Events
    event SharesUpdated(address indexed user, uint256 amount);
    event BalancesUpdated(address indexed user, uint256 amount);
    event TotalDepositsUpdated(uint256 amount);

    // Functions to update and get shares
    function globalsharesadd(address user, uint256 amount) public auth {
        _shares[user] += amount;
        emit SharesUpdated(user, amount);
    }

     function globalsharessub(address user, uint256 amount) public auth {
        _shares[user] -= amount;
        emit SharesUpdated(user, amount);
    }

    function shares(address user) public view returns (uint256) {
        return _shares[user];
    }

    // Functions to update and get balances
    function globalbalanceadd(address user, uint256 amount) public auth {
        _balances[user] += amount;
        emit BalancesUpdated(user, amount);
    }

    function globalbalancesub(address user, uint256 amount) public auth {
        _balances[user] -= amount;
        emit BalancesUpdated(user, amount);
    }

    function balance(address user) public view returns (uint256) {
        return _balances[user];
    }

    // Functions to update and get total deposits
    function globaltotaldepositadd(uint256 amount) public auth {
        _totalDeposits += amount;
        emit TotalDepositsUpdated(amount);
    }

       function globaltotaldepositsub(uint256 amount) public auth {
        _totalDeposits -= amount;
        emit TotalDepositsUpdated(amount);
    }

    function totaldeposits() public view returns (uint256) {
        return _totalDeposits;
    }



}
