//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Interface for the UniswapV3Twap contract
interface IUniswapV3Twap {
    function estimateAmountOut(address tokenIn, uint128 amountIn, uint32 secondsAgo) external view returns (uint amountOut);
    function token0() external view returns (address);
}

// Interface for the TestChainlink contract
interface ITestChainlink {
    function getLatestPrice() external view returns (int);
}

contract TokenPriceInUSD {
    IUniswapV3Twap public uniswapTwap;
    ITestChainlink public chainlinkOracle;
    address public owner;
    uint128 public defaultAmountIn = 1 ether;
    uint32 public defaultSecondsAgo = 5;

    constructor(address _uniswapTwap, address _chainlinkOracle, address _dsValue) {
        uniswapTwap = IUniswapV3Twap(_uniswapTwap);
        chainlinkOracle = ITestChainlink(_chainlinkOracle);
        owner = msg.sender;
    }

       modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setDefaults(uint128 newAmountIn, uint32 newSecondsAgo) external onlyOwner {
        defaultAmountIn = newAmountIn;
        defaultSecondsAgo = newSecondsAgo;
    }

    function getBCKETHPriceInUSD(uint128 amountIn, uint32 secondsAgo) public view returns (uint) {
        // Step 1: Fetch BCKETH price in ETH (wad format)
        uint bckGovInEth = uniswapTwap.estimateAmountOut(uniswapTwap.token0(), amountIn, secondsAgo);

        // Step 2: Fetch ETH price in USD (normal dollar format)
        int ethPriceInUsd = chainlinkOracle.getLatestPrice();

        // Ensure the price is not negative (This is a basic sanity check, you might want to handle more cases)
        require(ethPriceInUsd > 0, "Invalid ETH price");

        // Step 3: Convert BCKETH price to USD (wad format)
        uint bckGovInUsd = bckGovInEth * uint(ethPriceInUsd);
        
        return bckGovInUsd;
    }


}
