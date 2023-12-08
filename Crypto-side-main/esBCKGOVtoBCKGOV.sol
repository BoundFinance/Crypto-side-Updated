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
    mapping(address => uint256) public vestingRatio;
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
        updateVesting(msg.sender, amount);
        emit Deposited(msg.sender, amount);
    }


    function setpenalty(uint _penaltypercentage) public auth {
        require(_penaltypercentage <= 100);
        penaltypercentage = _penaltypercentage;
    }

    function claim() external {
        uint256 claimable = getClaimableAmount(msg.sender);
        require(claimable > 0, "No tokens available for claiming");
        BCKGOVToken.mint(msg.sender, claimable);
        lastClaimTime[msg.sender] = block.timestamp;
        emit Claimed(msg.sender, claimable);
    }

       function unlockPrematurely() external {
        require(block.timestamp + exitCycle - 3 days > time2fullRedemption[msg.sender], "Error");
        uint256 reservedAmount = getReservedAmountForVesting(msg.sender);
        uint256 preUnlockableAmount = getPreUnlockableAmount(msg.sender);
        uint256 claimableAmount = getClaimableAmount(msg.sender);
        uint256 amount = preUnlockableAmount + claimableAmount;
        uint burnamount = reservedAmount - preUnlockableAmount;

        // Apply penalty and send half to contract owner
        uint senttoOwner = burnamount * penaltypercentage / 100; 
        esBCKGOVToken.mint(owner, senttoOwner);

        // Update user's vesting
        vestingRatio[msg.sender] = 0;
        time2fullRedemption[msg.sender] = 0;

        BCKGOVToken.mint(msg.sender, amount);
        emit UnlockedPrematurely(msg.sender, amount);
    }

    function getPreUnlockableAmount(address user) public view returns (uint256) {
        uint256 reservedAmount = getReservedAmountForVesting(user);
        if (reservedAmount == 0) return 0;
        return (reservedAmount * (75e18 - ((time2fullRedemption[user] - block.timestamp) * 70e18) / (exitCycle / 1 days - 3) / 1 days)) / 100e18;
    }

    function UnlockedPrematurelyview(address _user) public view returns (uint) {
        require(block.timestamp + exitCycle - 3 days > time2fullRedemption[_user], "You can't Unlock before 3 dats have passed");
        uint256 reservedAmount = getReservedAmountForVesting(_user);
        uint256 preUnlockableAmount = getPreUnlockableAmount(_user);
        uint256 claimableAmount = getClaimableAmount(_user);
        uint256 amount = preUnlockableAmount + claimableAmount;
        uint burnamount = reservedAmount - preUnlockableAmount;
        return amount;
    }

    function updateVesting(address user, uint256 amount) internal {
        if (time2fullRedemption[user] > block.timestamp) {
            uint256 total = vestingRatio[user] * (time2fullRedemption[user] - block.timestamp) + amount;
            vestingRatio[user] = total / exitCycle;
            time2fullRedemption[user] = block.timestamp + exitCycle;
        } else {
            vestingRatio[user] = amount / exitCycle;
            time2fullRedemption[user] = block.timestamp + exitCycle;
        }
    }

    function getClaimableAmount(address user) public view returns (uint256) {
        if (time2fullRedemption[user] > lastClaimTime[user]) {
            uint256 amount = block.timestamp > time2fullRedemption[user]
                ? vestingRatio[user] * (time2fullRedemption[user] - lastClaimTime[user])
                : vestingRatio[user] * (block.timestamp - lastClaimTime[user]);
            return amount;
        }
        return 0;
    }

    function getReservedAmountForVesting(address user) public view returns (uint256) {
        if (time2fullRedemption[user] > block.timestamp) {
            return vestingRatio[user] * (time2fullRedemption[user] - block.timestamp);
        }
        return 0;
    }

    
}

