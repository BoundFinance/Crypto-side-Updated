pragma solidity ^0.8.19;

//TESTNET ONLY

import "Crypto-side-main/ds-token.sol";
import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/stake.sol";
import "Crypto-side-main/esBCKGOVemissions.sol";
import "Crypto-side-main/global.sol";

contract ControlPanel is DSAuth {
   

    DSToken public eUSDToken;
    DSToken public esBCKGOV;
    BCKSavingsAccount public savings;
    esBCKGOVEmissions public emission;
    Globals public global;
    address public yieldtoBCK;
    uint public percent = 55;

    uint256 public lastEmissionTime;
    uint256 public constant DAY = 86400; // Number of seconds in a day


    event savingsDeposited(uint256 Amount);
    event EmissionsDeposited(uint256 Amount);
    event YieldtoBCKDeposit(uint256 Amount);

    constructor(address _eUSDTokenAddress, address _esBCKGOV, address _savings, address _emissions, address _global, address _yieldtoBCK) {
        eUSDToken = DSToken(_eUSDTokenAddress);
        esBCKGOV = DSToken(_esBCKGOV);
        savings = BCKSavingsAccount(_savings);
        emission = esBCKGOVEmissions(_emissions);
        global = Globals(_global);
        yieldtoBCK = _yieldtoBCK;
        
    }

// interestBCKSavingsAccoun - TESTNET ONLY COMMENT OUT FOR MAINNET LAUNCH
    function interestBCKSavingsAccoun(uint _amountwei) public auth {
        esBCKGOV.mint(address(this), _amountwei);
        savings.distributeBCKGOV(_amountwei);
        emit savingsDeposited(_amountwei);
    }

   //For Mainnet Introduce the OrcalMain to get BCKGOV in USD. 
    function interestEmissions() public auth {
        // Ensure the function is called only once per day
        require(block.timestamp >= lastEmissionTime + DAY, "Can only be called once a day");

        uint total = global.totaldeposits();
        uint percentofshare = (total * percent) / 1000;
        uint perdayInterest = percentofshare / 365;

        // Update the last emission time
        lastEmissionTime = block.timestamp;

        esBCKGOV.mint(address(this), perdayInterest);
        emission.distributeBCKGOV(perdayInterest);
        emit EmissionsDeposited(perdayInterest);
    }

    function percentchanger (uint _percent) public auth {
        require(_percent < 1000, "interest is too high");
        percent = _percent;
    }


// interestStablecointoBCK - TESTNET ONLY COMMENT OUT FOR MAINNET LAUNCH
    function interestStablecointoBCK(uint _amountwei) public auth {
        eUSDToken.mint(address(this), _amountwei);
        eUSDToken.transferFrom(address(this), address(yieldtoBCK), _amountwei);
        emit YieldtoBCKDeposit(_amountwei);
    } 
}

//0x7B59df5207b204b50BcF26fD62C77Aa16791E874
