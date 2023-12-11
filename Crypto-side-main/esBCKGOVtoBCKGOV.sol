// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "Crypto-side-main/note.sol";
import "Crypto-side-main/ds-token.sol";

contract VestingContract is DSAuth, DSNote {
    DSToken public esBCKGOVToken;
    DSToken public BCKGOVToken;
    uint256 public constant exitCycle = 20 days;
    uint public penaltypercentage; //based on percentage so 10 = 10%, 1 = 1%


    mapping(address => uint256) public time2fullRedemption;
    mapping(address => uint256) public unstakeRatio;
    mapping(address => uint256) public lastClaimTime;

    event Deposited(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event UnlockedPrematurely(address indexed user, uint256 amount);

    constructor(address _esBCKGOVToken, address _BCKGOVToken) {
        esBCKGOVToken = DSToken(_esBCKGOVToken);
        BCKGOVToken = DSToken(_BCKGOVToken);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
         esBCKGOVToken.burn(msg.sender, amount);
        claim(msg.sender);
        uint256 total = amount;
        if (time2fullRedemption[msg.sender] > block.timestamp) {
            total += unstakeRatio[msg.sender] * (time2fullRedemption[msg.sender] - block.timestamp);
        }
        unstakeRatio[msg.sender] = total / exitCycle;
        time2fullRedemption[msg.sender] = block.timestamp + exitCycle;
        emit Deposited(msg.sender, amount);
    }

    function setpenalty(uint _penaltypercentage) public auth {
        require(_penaltypercentage <= 100);
        penaltypercentage = _penaltypercentage;
    }

    function claim(address _user) public {
        uint256 claimable = getClaimableAmount(_user);
        if(claimable > 0) {
             BCKGOVToken.mint(msg.sender, claimable);
        }
        lastClaimTime[_user] = block.timestamp;
        emit Claimed(_user, claimable);
    }


    function unlockPrematurely() external {
        require(block.timestamp + exitCycle - 3 days > time2fullRedemption[msg.sender], "Error");
        uint256 amount = getPreUnlockableAmount(msg.sender) + getClaimableAmount(msg.sender);
        uint burnamount = getReservedAmountForVesting(msg.sender) - getPreUnlockableAmount(msg.sender);
        if(amount > 0) {
        // Apply penalty and send half to contract owner
        uint senttoOwner = burnamount * penaltypercentage / 100; 
        esBCKGOVToken.mint(owner, senttoOwner);
        BCKGOVToken.mint(msg.sender, amount);
        }
        // Update user's vesting
        unstakeRatio[msg.sender] = 0;
        time2fullRedemption[msg.sender] = 0;

        emit UnlockedPrematurely(msg.sender, amount);
    }

    function UnlockedPrematurelyview(address _user) public view returns (uint) {
        require(block.timestamp + exitCycle - 3 days > time2fullRedemption[_user], "You can't Unlock before 3 dats have passed");
        uint256 amount = getPreUnlockableAmount(msg.sender) + getClaimableAmount(msg.sender);
        uint burnamount = getReservedAmountForVesting(msg.sender) - getPreUnlockableAmount(msg.sender);
        return amount;
    }

    function getPreUnlockableAmount(address user) public view returns (uint256 amount) {
        uint256 a = getReservedAmountForVesting(user);
        if (a == 0) return 0;
        amount = (a * (75e18 - ((time2fullRedemption[user] - block.timestamp) * 70e18) / (exitCycle / 1 days - 3) / 1 days)) / 100e18;
    }

    function getClaimableAmount(address user) public view returns (uint256 amount) {
        if (time2fullRedemption[user] > lastClaimTime[user]) {
            amount = block.timestamp > time2fullRedemption[user] ? unstakeRatio[user] * (time2fullRedemption[user] - lastClaimTime[user]) : unstakeRatio[user] * (block.timestamp - lastClaimTime[user]);
        }
    }

    function getReservedAmountForVesting(address user) public view returns (uint256 amount) {
        if (time2fullRedemption[user] > block.timestamp) {
            amount = unstakeRatio[user] * (time2fullRedemption[user] - block.timestamp);
        }
    }


    
}


