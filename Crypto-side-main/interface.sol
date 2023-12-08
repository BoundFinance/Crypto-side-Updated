// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IStablecointoBCK {
    function shares(address user) external view returns (uint256);
}

interface IOracleMain {
    function getBCKGovPriceInUSD() external view returns (uint256);
}
