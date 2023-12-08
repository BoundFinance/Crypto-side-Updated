pragma solidity ^0.8.19;

import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/note.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/BCKGOVemissions.sol";


interface StableSwap {
    function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface BCK {
    function mint(address guy, uint wad) external;
    function burn(address guy, uint wad) external;
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface emissions {
 function updateInterestCorrectionssub(address _user, uint256 _amount) external;
 function updateInterestCorrectionsadd(address _user, uint256 _amount) external;
}

interface IStabilityPool {
    function provideToSP(uint256 _amount) external;
    function withdrawFromSP(uint256 _amount) external;
    function claimableReward(address _depositor) external view returns (uint256);
    function claimReward(address recipient) external returns (uint256);
    function getTotalDebtTokenDeposits() external view returns (uint256);
    function getCompoundedDebtDeposit(address _depositor) external view returns (uint256);
    function claimCollateralGains(address recipient, uint256[] calldata collateralIndexes) external;
   function getDepositorCollateralGain(address _depositor) external view returns (uint256[] memory collateralGains);
  function collateralTokens(uint256 index) external view returns (IERC20);


}




contract StablecointoBCK is DSAuth, DSNote {
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    // Existing variables and events
    IERC20 public stableToken;
    IERC20 public USDC;
    BCK public bck;
    IStabilityPool public prisma;
    address public protocol;
    address public cashbackapp;
    uint public totalDepositedAsset;
    uint public bckminted;
    uint public reserveamountpercentage;
   

    uint256 public totalExcessReserve;
    uint256 constant internal magnitude = 2**128;
    uint256 public magnifiedExcessPerShare;
    mapping(address => int256) public magnifiedExcessCorrections;
    uint256 public totalDistributedExcess;
    mapping(address => uint256) public shares;
     mapping(address => uint256) public balance;
    mapping(address => uint256) public withdrawnExcess;
    uint256 public ratiostablebck;
    uint256 public ratiotoconvertback;
    uint public protocolshareofexcess;
    uint public cashbackappshare;

       // New state variable for tracking collateral claimed
    uint256 public collateralTypesCount = 3; // Set this to the number of collateral types
    mapping(address => uint256[collateralTypesCount]) public userCollateralClaimed;



    event Deposited(address indexed user, uint256 amount, uint256 bckMinted);
    event ExcessConverted(uint256 stableAmount);
    event Distributed(uint256 amount);
    event Exited(address indexed user, uint256 amount);
    emissions public emmission; 

    constructor(address _erc20Address, address _bck, address _cashback, address _protocol, address _prisma) public {
        stableToken = IERC20(_erc20Address);
        bck = BCK(_bck);
        cashbackapp = _cashback;
        protocol = _protocol;
        prisma = IStabilityPool(_prisma);
    }

     function setemission(address _eUSDtoBCK) external auth {
        emmission = emissions(_eUSDtoBCK);
    }

    function share(address _user) public view returns (uint256) {
        return shares[_user];
    }

    function totaldeposits() public view returns (uint256) {
        return totalDepositedAsset;
    }

function depositsStable(uint256 amount) public payable note {
        distribute();
        require(USDC.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(USDC.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        prisma.provideToSP(amount);
        
        uint amountadjusted = amount * ratiostablebck;
        totalDepositedAsset = totalDepositedAsset.add(amount);
        bckminted = bckminted.add(amountadjusted);

        uint256 userShare = amount;
        balance[msg.sender]= balance[msg.sender].add(amountadjusted);
        shares[msg.sender] = shares[msg.sender].add(userShare);

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .sub((magnifiedExcessPerShare.mul(amount)).toInt256Safe());
    
        emmission.updateInterestCorrectionssub(msg.sender, amount);

        bck.mint(msg.sender, amountadjusted);
        emit Deposited(msg.sender, amount, amountadjusted);
    }



    function setratios (uint amount, uint share, uint reserveamount) public auth {
        ratiostablebck = amount / 1000; // ratio to convert to stablecoin BCK
        ratiotoconvertback = 1000 / amount; // ratio to convert BCK back to stablecoin
        protocolshareofexcess = share / 100; // protcol shares of yield, the rest goes to cashbackapp
        reserveamountpercentage = reserveamount; // amount of APY left to users compared to Protocol & Cashback
    }


function exitStable(uint amount) public payable note {
        distribute();
        require(bck.balanceOf(msg.sender) >= amount, "you have insufficient balance");
        uint amountadjusted = amount * ratiotoconvertback;
        require(prisma.getTotalDebtTokenDeposits() >= amountadjusted, "you have insufficient balance");

        totalDepositedAsset = totalDepositedAsset.sub(amountadjusted);
        bckminted = bckminted.sub(amount);

        uint256 userShare = amount;
        shares[msg.sender] = shares[msg.sender].sub(userShare);
        balance[msg.sender]= balance[msg.sender].sub(amount);

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .add((magnifiedExcessPerShare.mul(amountadjusted)).toInt256Safe());

        emmission.updateInterestCorrectionsadd(msg.sender, amountadjusted);

        uint ratioofdepositedamount = prisma.getTotalDebtTokenDeposits() / totalDepositedAsset;
        uint adjusted = (amountadjusted * ratioofdepositedamount)
        prisma.withdrawFromSP(adjusted);

        bck.burn(msg.sender, amount);
        USDC.transferFrom(address(this), msg.sender, adjusted);

        emit Exited(msg.sender, amount);
    }

//calculate the rebased interest of LSDfi stablecoins
function convertExcess() internal  {

        uint claimablerewards = prisma.claimableReward(address(this));
        require(claimablerewards >= 0, "excess much be greater than 0");
        if(claimablerewards == 0) {
            return;    
        }

        uint256[] memory claimableCollateral = prisma.getDepositorCollateralGain(address(this));

        if(claimableRewards > 0) {
            prisma.claimReward(address(this)); // Claim Prisma rewards
        }

        // Claim each type of collateral gain
        for(uint256 i = 0; i < claimableCollateral.length; i++) {
            if(claimableCollateral[i] > 0) {
                uint256[] memory collateralIndexes = new uint256[](1);
                collateralIndexes[0] = i;
                prisma.claimCollateralGains(address(this), collateralIndexes);

            }
        }

        // Reserve for the users
        uint256 reserveForUsers = (claimablerewards * reserveamountpercentage) / 100;

        totalExcessReserve += reserveForUsers;

        if (totalDepositedAsset > 0) {
            magnifiedExcessPerShare = magnifiedExcessPerShare.add(
                (reserveForUsers).mul(magnitude).div(totalDepositedAsset)
            );
        }

        uint amountForConversion1 = amountForConversion - reserveForUsers;
        uint cashbackappreward = amountForConversion1 * (1 - protocolshareofexcess);
        cashbackappshare += cashbackappreward;
        uint protocolreward = amountForConversion1 - cashbackappreward;
        usdc.transferFrom(address(this), address(cashbackapp), cashbackappreward);
        usdc.transferFrom(address(this), address(protocol), protocolreward);
        emit Distributed(cashbackappreward);

    }

// WithdrawExcess - used to withdraw the excess funds from the users.
function withdrawExcess() public {
        distribute();
        uint256 _withdrawableExcess = withdrawableExcessOf(msg.sender);

         if (_withdrawableExcess > 0) {

      for(uint256 i = 0; i < collateralTypesCount; i++) {

            IERC20 collateralToken = prisma.collateralTokens()[i];
            uint256 collateralBalance = collateralToken.balanceOf(address(this));
            if( collateralBalance > 0 )

             uint rebaseAmount = collateralBalance * (_withdrawableExcess / totalExcessReserve);
             collateralToken.transferFrom(address(this), msg.sender, rebaseAmount);
        }  

            withdrawnExcess[msg.sender] += _withdrawableExcess;
            totalExcessReserve = totalExcessReserve.sub(_withdrawableExcess);
            stableToken.transferFrom(address(this), msg.sender, _withdrawableExcess);
        }

    }

// distribute - used to withdraw the share excess funds to the protocol.
function distribute() internal {
        convertExcess();
}    

function withdrawableExcessOf(address _owner) public view returns(uint256) {
        return accumulativeExcessOf(_owner).sub(withdrawnExcess[msg.sender]);
    }

function accumulativeExcessOf(address _owner) public view returns(uint256) {
        return magnifiedExcessPerShare.mul(shares[_owner]).toInt256Safe()
          .add(magnifiedExcessCorrections[_owner]).toUint256Safe().div(magnitude);
    }

}
