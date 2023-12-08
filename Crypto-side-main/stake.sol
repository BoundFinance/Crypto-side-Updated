pragma solidity ^0.8.12;

import "Crypto-side-main/erc20.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/ds-token.sol";

contract BCKSavingsAccount is DSAuth {
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  ERC20 public bck;
  ERC20 public esBCKGOV;
  DSToken[] public excessTokens;
 

  uint256 constant internal magnitude = 2**128;
  uint256 internal magnifiedInterestPerShare;
  uint256 public currentdistrbutedBCKGOV;
  uint public totalDistributed;
  mapping(address => int256) internal magnifiedInterestCorrections;
  mapping(address => uint256) public withdrawnInterest;

  mapping(address => uint256) public balances;
  uint256 public totalDeposits;
  event BCKGOVDistributed(address indexed from, uint256 value);


  constructor(address _bck, address _esBCKGOV) public {
    bck = ERC20(_bck);
    owner = msg.sender;
    esBCKGOV = ERC20(_esBCKGOV);
  }


function addExcessToken(address _tokenAddress) external auth {
      require(_tokenAddress != address(esBCKGOV) );
        excessTokens.push(DSToken(_tokenAddress));
}



function depositBCK(uint256 _amount) public {
    require(bck.transferFrom(msg.sender, address(this), _amount), "BCK transfer failed");

    // Before updating the balances and totalDeposits, adjust the magnifiedInterestCorrections
    // of the depositor based on their increased stake.
    magnifiedInterestCorrections[msg.sender] = magnifiedInterestCorrections[msg.sender]
        .sub( (magnifiedInterestPerShare.mul(_amount)).toInt256Safe() );

    balances[msg.sender] += (_amount);
    totalDeposits += (_amount);
}



function withdrawBCK(uint256 _amount) public {
    require(balances[msg.sender] >= _amount, "Insufficient BCK balance");

    // Before updating the balances and totalDeposits, adjust the magnifiedInterestCorrections
    // of the withdrawer based on their decreased stake.
    magnifiedInterestCorrections[msg.sender] = magnifiedInterestCorrections[msg.sender]
        .add( (magnifiedInterestPerShare.mul(_amount)).toInt256Safe() );

    balances[msg.sender] -= (_amount);
    totalDeposits -= (_amount);
    require(bck.transfer(msg.sender, _amount), "BCK transfer failed");
}



function distributeBCKGOV(uint256 _amount) public {
    // Check if the owner has enough USDC
    uint256 ownerBCKGOVBalance = esBCKGOV.balanceOf(msg.sender);
    require(ownerBCKGOVBalance >= _amount, "Owner has insufficient USDC balance");
    // Calculate the magnified interest per share
    if (totalDeposits > 0) {
        magnifiedInterestPerShare = magnifiedInterestPerShare.add(
            (_amount).mul(magnitude).div(totalDeposits)
        );
    }
     currentdistrbutedBCKGOV += _amount;
     totalDistributed += _amount;
    // Emit an event to inform external observers about the distribution
    emit BCKGOVDistributed(msg.sender, _amount);
    require(esBCKGOV.transferFrom(msg.sender, address(this), _amount), "USDC transfer failed");
}



function withdrawInterest() public {
    uint256 _withdrawableInterest = withdrawableInterestOf(msg.sender);
    
    if (_withdrawableInterest > 0) {

    for (uint i = 0; i < excessTokens.length; i++) {
            uint256 excessTokenBalance = excessTokens[i].balanceOf(address(this));
            uint256 excessDistribute = excessTokenBalance * (_withdrawableInterest / currentdistrbutedBCKGOV);
            require(excessTokens[i].transferFrom(address(this), msg.sender, excessDistribute), "Token transfer failed");
      } 
      withdrawnInterest[msg.sender] += (_withdrawableInterest);
      currentdistrbutedBCKGOV -= (_withdrawableInterest);
      require(esBCKGOV.transfer(msg.sender, _withdrawableInterest), "USDC transfer failed");
    }
  }


function withdrawableInterestOf(address _owner) public view returns(uint256) {
        return accumulativeInterestOf(_owner).sub(withdrawnInterest[_owner]);
}



//allows for yield bearing stablecoins to distribute yields fairly across users.
    function excessBCKGOVTest(address _user) public view returns (address[] memory, uint256[] memory, uint) {
        require(currentdistrbutedBCKGOV > 0, "THERE IS NO esBCKGOV INTEREST LEFT TO WITHDRAW");
        uint256 withdrawableInterest = withdrawableInterestOf(_user);
        address[] memory tokenAddresses = new address[](excessTokens.length);
        uint256[] memory withdrawableAmounts = new uint256[](excessTokens.length);

        for (uint i = 0; i < excessTokens.length; i++) {
            tokenAddresses[i] = address(excessTokens[i]);
            uint256 excessTokenBalance = excessTokens[i].balanceOf(address(this));
            uint256 rebaseAmount = excessTokenBalance * (withdrawableInterest / currentdistrbutedBCKGOV);
            withdrawableAmounts[i] = rebaseAmount;
        }
        return (tokenAddresses, withdrawableAmounts, withdrawableInterest);
    }



  function accumulativeInterestOf(address _owner) public view returns(uint256) {
    return magnifiedInterestPerShare.mul(balances[_owner]).toInt256Safe()
      .add(magnifiedInterestCorrections[_owner]).toUint256Safe() / magnitude;
  }
}