// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "Crypto-side-main/ds-token.sol";
import "Crypto-side-main/ds-auth.sol";

contract EthToEUSDExchange is DSAuth {
   

    DSToken public eUSDToken;
    uint256 public constant EXCHANGE_RATE = 1500; // 1 ETH = 1500 eUSD

    event Deposited(address indexed user, uint256 ethAmount, uint256 eUSDAmount);
    event Withdrawn(address indexed user, uint256 eUSDAmount, uint256 ethAmount);

    constructor(address _eUSDTokenAddress) {
        eUSDToken = DSToken(_eUSDTokenAddress);
    }

    // Allows users to deposit ETH and receive eUSD in return
    function deposit() external payable {
        uint256 eUSDAmt = (msg.value) * (EXCHANGE_RATE);
        eUSDToken.mint(msg.sender, eUSDAmt);

        emit Deposited(msg.sender, msg.value, eUSDAmt);
    }

    // Allows the owner to withdraw ETH from the contract
    function withdrawEth(uint256 _amount) external auth {
        require(address(this).balance >= _amount, "Insufficient ETH balance");
        payable(owner).transfer(_amount);

        emit Withdrawn(owner, 0, _amount);
    }

    // Allows the owner to withdraw eUSD from the contract
    function withdrawEUSD(uint256 _amount) external auth {
        require(eUSDToken.balanceOf(address(this)) >= _amount, "Insufficient eUSD balance");
        eUSDToken.transfer(owner, _amount);

        emit Withdrawn(owner, _amount, 0);
    }

      // Fallback function to accept ETH when sent directly to the contract address
    receive() external payable {
        uint256 eUSDAmt = (msg.value) * (EXCHANGE_RATE);
        require(eUSDToken.balanceOf(address(this)) >= eUSDAmt, "Insufficient eUSD balance in contract");
        eUSDToken.transfer(msg.sender, eUSDAmt);

        emit Deposited(msg.sender, msg.value, eUSDAmt);
    }
}
