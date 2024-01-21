pragma solidity ^0.8.19;

import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/note.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/esBCKGOVemissions.sol";
import "Crypto-side-main/interfaceParallax.sol";


contract ParallaxBound is DSAuth, DSNote {
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    IERC20 public stableToken;
    IERC20 public WETH;
    ICALMRouter calmRouter;
    IUniswapV3SwapRouter public uniswapRouter;
    IUniswapV3Pool public uniswapPool;
    address public protocol;
    address public cashbackapp;
    uint public totalDepositedAsset;
    uint public reserveamountpercentage;
    uint public protocolshareofexcess;
    uint public RewardLedger;
    uint public cashbackappshare;
    uint public totalDepositedAssetUSD;
    uint256 public totalExcessReserve;
    uint256 constant internal magnitude = 2**128;
    uint256 public magnifiedExcessPerShare;
    mapping(address => int256) public magnifiedExcessCorrections;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public withdrawnExcess;
    mapping(address => uint256) public sharesUSD;
    mapping(address => uint256) public BackUpbalanceCount;
    mapping(address => bool) public hasDeposited;


    event Deposited(address indexed user, uint256 amount);
    event ExcessConverted(uint256 stableAmount);
    event DistributedToReserve(uint time, uint256 amount);
    event Distributed(uint256 amount);
    event Exited(address indexed user, uint256 amount);
    event NewDepositor(address indexed user, uint256 amount);


    emissions public emmission; 
    global public globals;
    cashbackcontract public cash;

    constructor(address _erc20Address, address _cashback, address _protocol, address _WETH, address _router, address _poolAddress) {
        stableToken = IERC20(_erc20Address);
        WETH = IERC20(_WETH);
        cashbackapp = _cashback;
        protocol = _protocol;
        calmRouter = ICALMRouter(_router);
        uniswapPool = IUniswapV3Pool(_poolAddress);
    }

    function setemission(address _bckgovemissions) external auth {
        emmission = emissions(_bckgovemissions);
    }

    function setglobal(address _globaladdress) external auth {
        globals = global(_globaladdress);
    }

    function setcashbackcontract(address _cashbackappcontract) public auth {
        cash = cashbackcontract(_cashbackappcontract);
    }

    function share(address _user) public view returns (uint256) {
        return shares[_user];
    }

    function totaldeposits() public view returns (uint256) {
        return totalDepositedAsset;
    }

    function setPercentages(uint _percentage, uint _protocolSharePercent) public auth {
        require( _percentage < 100 && _protocolSharePercent < 100);
        reserveamountpercentage = _percentage;
        protocolshareofexcess = _protocolSharePercent;

    }
    /* The deposit functions, first transfers the WETH to the contract, the contract then swaps WETH
       with USDC.e using depositERC20Token() then we hit depositToken, and then we add the global ledger.
       and shares, sharesUSD. We are also recording the first time users are depositing so we can pass through their 
       address in orcale.
     */

    function depositsWETH(uint256 amount) public {
        convertExcess();
        require(amount > 0, "Amount must be greater than 0");
        require(WETH.balanceOf(msg.sender) >= amount, "Insufficient WETH balance");
        address user = msg.sender;

        WETH.transferFrom(msg.sender, address(this), amount);
        WETH.approve(address(calmRouter), amount);
        
        ICALMRouter.AssetConfig memory config = ICALMRouter.AssetConfig({
            pair: ICALMCore.Pair({
                token0: address(WETH),  
                token1: address(stableToken)   
            }),
            path: abi.encodePacked(address(WETH), uint24(500), address(stableToken))
        });

        ICALMCore.Amounts memory depositedAmounts = calmRouter.depositERC20Token(
            config, 
            amount, 
            [uint256(0), 0, 0, 0],
            0
        );

        address token0 = address(WETH);
        address token1 = address(stableToken);
        ICALMCore.Pair memory pair = ICALMCore.Pair({token0: token0, token1: token1});

        calmRouter.depositTokens(
        pair,
        ICALMCore.Amounts({
            amount0: depositedAmounts.amount0, 
            amount1: depositedAmounts.amount1
         }),
    [uint256(0), uint256(0), uint256(0), uint256(0)] // Corrected array with uint256 types
    );

        uint amountUSD = ethToUsdc(amount);
        totalDepositedAsset += amount;
        shares[msg.sender] += amount;
        BackUpbalanceCount[msg.sender] += amount;
        sharesUSD[msg.sender] += amountUSD;
        totalDepositedAssetUSD += amountUSD;

        globals.globalsharesadd(user, amountUSD); 
        globals.globaltotaldepositadd(amountUSD);

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .sub((magnifiedExcessPerShare.mul(amount)).toInt256Safe());

        emmission.updateInterestCorrectionssub(user, amountUSD);

        if (!hasDeposited[msg.sender]) {
        hasDeposited[msg.sender] = true;
        emit NewDepositor(msg.sender, amount);
        }


        emit Deposited(msg.sender, amount);
    }


    /* Exit function, user has to exit full position. We are going to convert USDC.e to WETH and then send WETH back 
    to user. 
     */

    function exitETH() public {
        convertExcess();
        OrcaleuserShares(msg.sender);

        uint256 userShares = shares[msg.sender];
        uint256 amountUSD = sharesUSD[msg.sender];

        require(userShares > 0, "You don't have enough shares to withdraw");
        withdrawExcess();

        uint128 withdrawalAmount = uint128(calculateWithdrawalAmount(userShares));
        address token0 = address(WETH);
        address token1 = address(stableToken);

        ICALMCore.Pair memory pair = ICALMCore.Pair({token0: token0, token1: token1});

        ICALMCore.Amounts memory amountsWithdrawn = calmRouter.withdrawTokens(
            pair,
            withdrawalAmount,
            [uint256(0), uint256(0), uint256(0), uint256(0)], // uint256[3] array initialized with zeros
            [uint256(0), uint256(0), uint256(0)] // amountOutMinOuter as a single uint256 value
        );

        uint256 additionalWETH = swap(amountsWithdrawn.amount1, 0, token1, token0);
        uint256 totalWETH = amountsWithdrawn.amount0 + additionalWETH;
        require(WETH.transferFrom(address(this), msg.sender, totalWETH), "WETH transfer failed");

    
        totalDepositedAsset -= userShares;
        shares[msg.sender] -= userShares;

        globals.globalsharessub(msg.sender, amountUSD); 
        globals.globaltotaldepositsub(amountUSD);

        totalDepositedAssetUSD -= amountUSD;
        sharesUSD[msg.sender] -= amountUSD;

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .add((magnifiedExcessPerShare.mul(userShares)).toInt256Safe());
        emmission.updateInterestCorrectionsadd(msg.sender, amountUSD);

        emit Exited(msg.sender, totalWETH);
    }

    function calculateWithdrawalAmount(uint256 userShares) public view returns (uint256) {
        (uint256 totalContractShares, , , , ) = calmRouter.userInfo(address(this));
        uint256 userShareOfPool = (userShares * totalContractShares) / totaldeposits();
        return userShareOfPool;
    }

    /* Claim rewards, is used to claim the rewards from all users position, and we then distribute the rewards based on
    deposit size on convertExcess(). We also convert all rewards into USDC.e
     */


    function claimRewards() public auth {
        (,uint256 rewards, , , ) = calmRouter.userInfo(address(this));
        require(rewards > 0, "There are no rewards to claim");

        RewardLedger += rewards;
        address token0 = address(WETH);
        address token1 = address(stableToken);

        ICALMCore.Pair memory pair = ICALMCore.Pair({token0: token0, token1: token1});

        ICALMCore.Amounts memory amountsWithdrawn = calmRouter.claimTokens(
            pair,
            [uint256(0), uint256(0), uint256(0)], // uint256[3] array initialized with zeros
            false
        );

        
        uint256 usdcConversion = swap(amountsWithdrawn.amount0, 0, token0, token1);
        uint256 totalUSDC = amountsWithdrawn.amount1 + usdcConversion;
        RewardLedger += totalUSDC;
    }

    function convertExcess() internal {
        uint excessAmount = RewardLedger - totalExcessReserve;
        require(excessAmount >= 0, "excess must be greater than 0");
        uint256 reserveForUsers = (excessAmount * reserveamountpercentage) / 100;

        totalExcessReserve += reserveForUsers;
        emit DistributedToReserve(block.timestamp, reserveForUsers);

        if (totalDepositedAsset > 0) {
            magnifiedExcessPerShare = magnifiedExcessPerShare.add(
                (reserveForUsers).mul(magnitude).div(totalDepositedAsset)
            );
        }
        uint amountForConversion1 = excessAmount - reserveForUsers;

        uint cashbackappreward = amountForConversion1 * ((100 - protocolshareofexcess) / 100);
        cashbackappshare += cashbackappreward;
        uint protocolreward = amountForConversion1 - cashbackappreward;
        cash.depositUSDC(cashbackappreward);

        stableToken.transferFrom(address(this), address(protocol), protocolreward);
        emit Distributed(cashbackappreward);
    }

    function withdrawExcess() public {

        convertExcess();
        uint256 _withdrawableExcess = withdrawableExcessOf(msg.sender);
        if (_withdrawableExcess > 0) {
            withdrawnExcess[msg.sender] += _withdrawableExcess;
            totalExcessReserve = totalExcessReserve.sub(_withdrawableExcess);
            stableToken.transferFrom(address(this), msg.sender, _withdrawableExcess);
        }
    }

    function withdrawableExcessOf(address _owner) public view returns(uint256) {
        return accumulativeExcessOf(_owner).sub(withdrawnExcess[msg.sender]);
    }

    function accumulativeExcessOf(address _owner) public view returns(uint256) {
        return magnifiedExcessPerShare.mul(shares[_owner]).toInt256Safe()
          .add(magnifiedExcessCorrections[_owner]).toUint256Safe().div(magnitude);
    }

    function getLatestPrice() public view returns (uint256) {
        (uint160 sqrtPriceX96,,,,,,) = uniswapPool.slot0();
        uint256 priceX96 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        // Scale price for 18 decimal places
        return priceX96 >> (96 * 2 - 18 * 2);
    }

    function ethToUsdc(uint256 ethAmountInWei) public view returns (uint256) {
        uint256 ethPriceInUsdc = getLatestPrice(); // Price of 1 ETH in USDC, with USDC scaled to 18 decimals
        uint256 usdcAmountInWei = (ethAmountInWei * ethPriceInUsdc) / 1e18; // Convert ETH amount in wei to USDC amount in wei
        return usdcAmountInWei;
    }


function swap(uint256 Amount, uint256 amountOutMin, address token0, address token1) internal returns (uint256) {
    IERC20 Token0 = IERC20(token0);
    require(Token0.balanceOf(address(this)) >= Amount, "Insufficient token balance");
    Token0.approve(address(uniswapRouter), Amount);

    uint256 AmountSwapped = uniswapRouter.exactInputSingle(
        IUniswapV3SwapRouter.exactInputSingleParams({
            tokenIn: token0,
            tokenOut: token1,
            fee: 500,  // the pool fee
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: Amount,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        })
    );

    return AmountSwapped;
}


 /* As global, and emissions ledger are recorded in USD. We need to keep updating the position value in ETH for all users
 as well as the totalDeposit value. 
*/



function OrcaleuserShares(address _user) public  {
    // If the user has no shares in ETH or USD, exit the function
 
    uint sharesOfUserETH = shares[_user];
    uint sharesOfUserUSD = sharesUSD[_user];

    uint price = getLatestPrice();
    uint256 usdcAmountInWei = (sharesOfUserETH * price) / 1e18;

    if(usdcAmountInWei == sharesOfUserUSD) {
        return; 
    } else if (usdcAmountInWei > sharesOfUserUSD) {
       uint priceDifference = usdcAmountInWei - sharesOfUserUSD;
       sharesUSD[_user] += priceDifference;
       globals.globalsharesadd(_user, priceDifference); 
       globals.globaltotaldepositadd(priceDifference);
       emmission.updateInterestCorrectionssub(_user, priceDifference); 
       totalDepositedAssetUSD += priceDifference;

    } else if(usdcAmountInWei < sharesOfUserUSD) {
        uint priceDifference = sharesOfUserUSD - usdcAmountInWei;
        sharesUSD[_user] -= priceDifference;
        globals.globalsharessub(_user, priceDifference); 
        globals.globaltotaldepositsub(priceDifference);
        emmission.updateInterestCorrectionsadd(_user, priceDifference); 
        totalDepositedAssetUSD -= priceDifference;
    }
}

}

