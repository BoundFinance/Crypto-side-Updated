pragma solidity ^0.8.12;

import "Crypto-side-main/ds-token.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/interface.sol";
import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/stake.sol";



interface G {
  function balance(address owner) external view returns (uint256);
  function shares(address owner) external view returns (uint256);
  function totaldeposits() external view returns (uint256);
}

contract esBCKGOVEmissions is DSAuth {
  using SafeMathUint for uint256;
  using SafeMathInt for int256;
   IStablecointoBCK public stablecointoBCK; // Your StablecointoBCK contract
  //  IOracleMain public oracleMain; // Your OracleMain contract to get BCKGov price

  DSToken public BCKGov;
  DSToken public esBCKGov;
  BCKSavingsAccount public stake;
 

  uint256 constant internal magnitude = 2**128;
  uint256 public magnifiedInterestPerShare2;
  uint256 public currentdistrbutedBCKGOV;
  uint256 public DiscountedBCKGOVAmount;
  uint256 public liquidationrewardfee = 5;
  uint public discountrate = 40;
  uint public protocolorbcksavingsrate = 20;
  mapping(address => int256) public magnifiedInterestCorrections2;
  mapping(address => uint256) public withdrawnInterest;
  uint public minimumstakeshares;
  mapping(address => uint256) public balances;
  uint256 public totalDeposits;
  event USDCDistributed(address indexed from, uint256 value);
  G public global; 


  constructor(address _BCKGov, address _esBCKGov)  {
    BCKGov = DSToken(_BCKGov);
    esBCKGov = DSToken(_esBCKGov);
    owner = msg.sender;
  }

    function setStablecointoBCK(address _stablecointoBCK) external auth {
        stablecointoBCK = IStablecointoBCK(_stablecointoBCK);
    }

    function setstake(address _Stake) external auth {
      stake = BCKSavingsAccount(_Stake);
    }

    function testStake() public view returns (uint) {
      uint balanceamount = stake.balances(msg.sender);
      return balanceamount;
    }

     function setratios(uint _minimumstakeshares, uint _penalty, uint _discountrate, uint _protocolorbcksavingsrate) public auth {
        require(_penalty <= 100 && _discountrate <= 100 && _protocolorbcksavingsrate <= 100);
        liquidationrewardfee = _penalty;
        minimumstakeshares = _minimumstakeshares;
        discountrate = _discountrate;
        protocolorbcksavingsrate = _protocolorbcksavingsrate;
    }

    function setG(address _globaladdress) external auth {
        global = G(_globaladdress);
    }


function updateInterestCorrectionssub(address _user, uint256 _amount) public auth {
        // Access control checks (like onlyOwner or a specific modifier)
        int256 correction = magnifiedInterestPerShare2.mul(_amount).toInt256Safe();
        magnifiedInterestCorrections2[_user] = magnifiedInterestCorrections2[_user].sub(correction);
    }

function updateInterestCorrectionsadd(address _user, uint256 _amount) public auth {
        // Access control checks (like onlyOwner or a specific modifier)
        int256 correction = magnifiedInterestPerShare2.mul(_amount).toInt256Safe();
        magnifiedInterestCorrections2[_user] = magnifiedInterestCorrections2[_user].add(correction);
  }


function distributeBCKGOV(uint256 _amount) public {
    // Check if the owner has enough USDC
    uint256 ownerBCKGOVBalance = esBCKGov.balanceOf(msg.sender);
    require(ownerBCKGOVBalance >= _amount, "Owner has insufficient USDC balance");
    uint _totaldeposits =global.totaldeposits(); 
    // Calculate the magnified interest per share
    if (_totaldeposits > 0) {
        magnifiedInterestPerShare2 = magnifiedInterestPerShare2.add(
            (_amount).mul(magnitude).div(_totaldeposits)
        );
    }
    currentdistrbutedBCKGOV = currentdistrbutedBCKGOV + _amount;
    // Emit an event to inform external observers about the distribution
    emit USDCDistributed(msg.sender, _amount);
    // Transfer the USDC from the owner to the contract
    require(esBCKGov.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");
}


  function meetsStakingRequirement(address _user) public view returns (bool) {
        uint256 shares = global.shares(_user);
        if(shares < minimumstakeshares) {
          return false;
        }
        uint256 requiredBCK = shares.mul(25).div(1000); // Assuming 2.5% in BCK is the requirement
        uint256 userBCKBalance = stake.balances(msg.sender);
        uint256 priceBCKGovInUSD = 1500; //replaced with oracleMain.getBCKGovPriceInUSD();
        return userBCKBalance.mul(priceBCKGovInUSD) >= requiredBCK;
  }

  function setliquidationrewardfee(uint _penalty) public auth {
    require(_penalty <= 100);
    liquidationrewardfee = _penalty;
  }

  function buyOutNonMaintainedShares(address _user) public {
        require(!meetsStakingRequirement(_user), "User meets staking requirement");
        require(msg.sender != address(_user));

        uint rewardToBuy = withdrawableInterestOf(_user);
        uint providedpenalty = (rewardToBuy * liquidationrewardfee) / 100;
        uint PurchasableesBCKGOV = rewardToBuy - providedpenalty;

        esBCKGov.transferFrom(address(this), address(msg.sender), providedpenalty);

        // Update the withdrawn interest to reflect the buy out
        DiscountedBCKGOVAmount += (PurchasableesBCKGOV);
        currentdistrbutedBCKGOV -= (rewardToBuy);
        withdrawnInterest[_user] += (rewardToBuy);
  }


 function buyDiscountedesBCKGOV(uint _amount) public {
    require(BCKGov.balanceOf(msg.sender) >= _amount);
    require(_amount <= DiscountedBCKGOVAmount);

    DiscountedBCKGOVAmount -= _amount;

    uint costtoBuy = (_amount * discountrate) / 100;
    uint protocolorBCKsavingsfee = (costtoBuy * protocolorbcksavingsrate) / 100;
    uint burnrate = costtoBuy - protocolorBCKsavingsfee;

    BCKGov.transferFrom(msg.sender, address(owner), protocolorBCKsavingsfee);
    BCKGov.burn(msg.sender, burnrate);
    esBCKGov.transferFrom(address(this), msg.sender, _amount);
 }

  function getUserRewardInfo(address _user) public view returns (bool canWithdraw, uint256 rewardAmount, uint256 costToBuyInBCKGOV) {
        bool stakingRequirementMet = meetsStakingRequirement(_user);
        uint256 reward = withdrawableInterestOf(_user);
        uint256 costToBuyInBCKGOV = reward.div(2); // Cost in BCKGov
        return (stakingRequirementMet, reward, stakingRequirementMet ? 0 : costToBuyInBCKGOV);
  }

     function withdrawInterest() public {
        uint256 withdrawableInterest = withdrawableInterestOf(msg.sender);

        // Then, process the withdrawal of BCKGov and esBCKGov tokens
        if (withdrawableInterest > 0) {
            withdrawnInterest[msg.sender] += (withdrawableInterest);
            currentdistrbutedBCKGOV = currentdistrbutedBCKGOV - withdrawableInterest;
            require(esBCKGov.transfer(msg.sender, withdrawableInterest), "USDC transfer failed");
        }
    }

    // Modified view function to calculate withdrawable interest in terms of excess tokens
    function excessBCKGOVTest(address _user) public view returns (uint) {
        require(currentdistrbutedBCKGOV > 0, "THERE IS NO esBCKGOV INTEREST LEFT TO WITHDRAW");
        uint256 withdrawableInterest = withdrawableInterestOf(_user);
        return (withdrawableInterest);
    }



  function withdrawableInterestOf(address _owner) public view returns(uint256) {
        return accumulativeInterestOf(_owner).sub(withdrawnInterest[_owner]);
    }


  function accumulativeInterestOf(address _owner) public view returns(uint256) {
    return magnifiedInterestPerShare2.mul(global.shares(_owner)).toInt256Safe()
      .add(magnifiedInterestCorrections2[_owner]).toUint256Safe() / magnitude;
  }
}
