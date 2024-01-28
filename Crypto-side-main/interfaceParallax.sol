interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface emissions {
 function updateInterestCorrectionssub(address _user, uint256 _amount) external;
 function updateInterestCorrectionsadd(address _user, uint256 _amount) external;
}

interface IWETH {
    // Convert ETH to WETH
    function deposit() external payable;

    // Convert WETH to ETH
    function withdraw(uint256 amount) external;
}


interface global {
 function globalsharesadd(address _user, uint _amount) external;
 function globalsharessub(address _user, uint _amount) external;
 function globalbalanceadd(address _user, uint _amount) external;
 function globalbalancesub(address _user, uint _amount) external;
 function globaltotaldepositadd(uint _amount) external;
 function globaltotaldepositsub(uint _amount) external;
}

interface cashbackcontract {
  function depositUSDC(uint256 _amount) external;
}

library ICALMCore {
    struct Pair {
        address token0;
        address token1;
    }

    struct Amounts {
        uint256 amount0;
        uint256 amount1;
    }
}

interface ICALMRouter {

struct AssetConfig {
        // Define the properties of AssetConfig here
        ICALMCore.Pair pair;
        bytes path;
    }

    function depositERC20Token(
        AssetConfig calldata config, 
        uint256 amount, 
        uint256[4] calldata amountsOutMinInner, 
        uint256 amountOutMinOuter
    ) external returns (ICALMCore.Amounts memory amountsOut);


    function withdrawTokens(
        ICALMCore.Pair calldata pair,
        uint128 shares,
        uint256[4] calldata amountsOutMinInner,
        uint256[3] calldata claimAmountsOut
    ) external returns (ICALMCore.Amounts memory amountsOut);

    function userInfo(address user) external view returns (
        uint256 shares, 
        uint256 rewards, 
        uint256 paidPerShare, 
        uint64 createTimestamp, 
        uint64 updateTimestamp
    );

      function claimTokens(
        ICALMCore.Pair calldata pair,
        uint256[3] calldata amountsOutMinInner,
        bool noSwap
    ) external returns (ICALMCore.Amounts memory claimed);

    function depositTokens(
        ICALMCore.Pair calldata pair,
        ICALMCore.Amounts calldata amounts,
        uint256[4] calldata amountsOutMinInner
    ) external returns (ICALMCore.Amounts memory amountsOut);

    function paused() external view returns (bool);
    
}

interface IUniswapV3SwapRouter {
    function exactInputSingle(
        exactInputSingleParams calldata params
    ) external returns (uint256 amountOut);

    struct exactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
}
interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}



