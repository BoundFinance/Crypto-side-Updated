// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "Crypto-side-main/esBCKGOVemissions.sol";
import "Crypto-side-main/esBCKGOVtoBCKGOV.sol";
import "Crypto-side-main/global.sol";
import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/ds-guard.sol";
import "Crypto-side-main/yieldstabletoBCK.sol";
import "Crypto-side-main/stake.sol";
import "Crypto-side-main/ds-token.sol";
import "Crypto-side-main/buyeUSDandBCKGOV.sol";

contract TokenFactory {
    function newTok(string memory name) public returns (DSToken token) {
        token = new DSToken(name);
        token.setOwner(msg.sender);
    }
}

contract EmissionsFactory {
    function newEmissions(address _BCKGov, address _esBCKGov) public returns (esBCKGOVEmissions esBCKGOV) {
        esBCKGOV = new esBCKGOVEmissions(_BCKGov, _esBCKGov);
        esBCKGOV.setOwner(msg.sender);
    }
}

contract YieldToBCKFactory {
    function newYieldToBCK(address _yieldBearingstable, address _bck, address _cashbackapp, address _protocol) public returns (StablecointoBCK yieldtoBCK) {
        yieldtoBCK = new StablecointoBCK(_yieldBearingstable, _bck, _cashbackapp, _protocol);
        yieldtoBCK.setOwner(msg.sender);
    }
}

contract VestingContractFactory {
    function esBCKGOVtoBCKGOV(address _BCKGov, address _esBCKGOV) public returns (VestingContract esBCKGOVconverter) {
        esBCKGOVconverter = new VestingContract(_BCKGov, _esBCKGOV);
        esBCKGOVconverter.setOwner(msg.sender);
    }
}

contract GlobalsFactory {
    function globalParams() public returns (Globals globalparam) {
        globalparam = new Globals();
        globalparam.setOwner(msg.sender);
    }
}

contract SavingsAccountFactory {
    function stake(address _bck,  address _esBCKGOV) public returns (BCKSavingsAccount savingsaccount) {
        savingsaccount = new BCKSavingsAccount(_bck, _esBCKGOV);
        savingsaccount.setOwner(msg.sender);
    }
}

contract GuardFactory {
    function newDad() public returns (DSGuard dad) {
        dad = new DSGuard();
        dad.setOwner(msg.sender);
    }
}

contract buyTokensTestnet {
    function BuyToken(address __eUSDTokenAddress) public returns (EthToEUSDExchange buy) {
        buy = new EthToEUSDExchange(__eUSDTokenAddress);
        buy.setOwner(msg.sender);
    }
}


contract Deployer is DSAuth {
    DSToken public bck;
    DSToken public stabletoken;
    DSToken public esBCKGOV;
    DSToken public BCKGOV;
    Globals public globalparam;
    StablecointoBCK public eusdtoBCK;
    esBCKGOVEmissions public Governanceemissions;
    VestingContract public vest;
    BCKSavingsAccount public bcksavin; 
    DSGuard public dad;
    EthToEUSDExchange public buyseUSD;
    EthToEUSDExchange public buysBCKGOV;

    TokenFactory public tokenFactory;
    EmissionsFactory public emissionsFactory;
    YieldToBCKFactory public yieldToBCKFactory;
    VestingContractFactory public vestingContractFactory;
    GlobalsFactory public globalsFactory;
    SavingsAccountFactory public savingsAccountFactory;
    GuardFactory public guardFactory;
    buyTokensTestnet public BuyTokensStableandBCKGov;

    uint8 public step = 0;

    constructor(
        TokenFactory _tokenFactory,
        EmissionsFactory _emissionsFactory,
        YieldToBCKFactory _yieldToBCKFactory,
        VestingContractFactory _vestingContractFactory,
        GlobalsFactory _globalsFactory,
        SavingsAccountFactory _savingsAccountFactory,
        GuardFactory _guardFactory,
        buyTokensTestnet _BuyTokensStableandBCKGov
    )  {
        owner = msg.sender;
        tokenFactory = _tokenFactory;
        emissionsFactory = _emissionsFactory;
        yieldToBCKFactory = _yieldToBCKFactory;
        vestingContractFactory = _vestingContractFactory;
        globalsFactory = _globalsFactory;
        savingsAccountFactory = _savingsAccountFactory;
        guardFactory = _guardFactory;
        BuyTokensStableandBCKGov = _BuyTokensStableandBCKGov;
    }


    function makeTokens() public auth {
        require(step == 0);
        bck = tokenFactory.newTok("BCK");
        stabletoken = tokenFactory.newTok("eUSD");
        esBCKGOV = tokenFactory.newTok("esBCKGOV");
        BCKGOV = tokenFactory.newTok("BCKGOV");
        globalparam = globalsFactory.globalParams();
        step += 1;
    }

    function makeContracts() public auth {
        require(step == 1);
        require(address(bck) != address(0x0));
        require(address(stabletoken) != address(0x0));
        require(address(esBCKGOV) != address(0x0));
        require(address(globalparam) != address(0x0));
        eusdtoBCK = yieldToBCKFactory.newYieldToBCK(address(stabletoken), address(bck), address(owner), address(owner));
        Governanceemissions = emissionsFactory.newEmissions(address(BCKGOV), address(esBCKGOV));
        vest = vestingContractFactory.esBCKGOVtoBCKGOV(address(esBCKGOV), address(BCKGOV));
        bcksavin = savingsAccountFactory.stake(address(BCKGOV), address(esBCKGOV));
        buyseUSD = BuyTokensStableandBCKGov.BuyToken(address(stabletoken));
        buysBCKGOV = BuyTokensStableandBCKGov.BuyToken(address(BCKGOV));
        step += 1;
    }

    // eUSDtoBCK 
    // Ratios:
    // 2:1 collateral ratio to BCK compared to $eUSD
    // 25% taken from any interest earnt from the yieldbearing token $eUSD
    // then 20% or 5% of total interest generated to protocol, and the rest to the cashback

    // setminimum: miniumum collateral you have to deposit to be qualified for BCKGOV emissions
    // this is set to 100 $eUSD 

    // setpenalty: Is the penalty given to users esBCKGOV when they want to convert to BCKGOV before vesting period.


    function config() public auth {
        require(step == 2);
        eusdtoBCK.setemission(address(Governanceemissions));
        eusdtoBCK.setglobal(address(globalparam));
        eusdtoBCK.setratios(2000, 20, 75);
        Governanceemissions.setratios(5, 100000000000000000000, 40, 20);
        Governanceemissions.setStablecointoBCK(address(eusdtoBCK));
        Governanceemissions.setG(address(globalparam));
        Governanceemissions.setstake(address(bcksavin));
        vest.setpenalty(20);
        step += 1;
    }

      function S(string memory _func) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked(_func)));
    }

    function configAuth() public auth {
        require(step == 3);
       

        dad = guardFactory.newDad(); 

        bck.setAuthority(dad);
        bck.setOwner(owner);
        stabletoken.setAuthority(dad);
        stabletoken.setOwner(owner);
        esBCKGOV.setAuthority(dad);
        esBCKGOV.setOwner(owner);
        BCKGOV.setAuthority(dad);
        BCKGOV.setOwner(owner);
        globalparam.setAuthority(dad);
        globalparam.setOwner(owner);
        eusdtoBCK.setAuthority(dad);
        eusdtoBCK.setOwner(owner);
        Governanceemissions.setAuthority(dad);
        Governanceemissions.setOwner(owner);
        vest.setAuthority(dad);
        vest.setOwner(owner);
        bcksavin.setAuthority(dad);
        bcksavin.setOwner(owner);
        buyseUSD.setAuthority(dad);
        buyseUSD.setOwner(owner);
        buysBCKGOV.setAuthority(dad);
        buysBCKGOV.setOwner(owner);

        dad.permit(address(eusdtoBCK), address(bck), S("mint(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(bck), S("burn(address,uint256)"));

        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("updateInterestCorrectionssub(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("updateInterestCorrectionsadd(address,uint256)"));
        
        dad.permit(address(eusdtoBCK), address(globalparam), S("globalsharesadd(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(globalparam), S("globalsharessub(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(globalparam), S("globalbalanceadd(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(globalparam), S("globalbalancesub(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(globalparam), S("globaltotaldepositadd(uint256)"));
        dad.permit(address(eusdtoBCK), address(globalparam), S("globaltotaldepositsub(uint256)"));

        
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globalsharesadd(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globalsharessub(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globalbalanceadd(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globalbalancesub(address,uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globaltotaldepositadd(uint256)"));
        dad.permit(address(eusdtoBCK), address(Governanceemissions), S("globaltotaldepositsub(uint256)"));
        
        dad.permit(address(vest), address(BCKGOV), S("mint(address,uint256)"));
        dad.permit(address(vest), address(BCKGOV), S("burn(address,uint256)"));
        dad.permit(address(vest), address(esBCKGOV), S("mint(address,uint256)"));
        dad.permit(address(vest), address(esBCKGOV), S("burn(address,uint256)"));

        dad.permit(address(Governanceemissions), address(BCKGOV), S("mint(address,uint256)"));
        dad.permit(address(Governanceemissions), address(BCKGOV), S("burn(address,uint256)"));
        dad.permit(address(Governanceemissions), address(esBCKGOV), S("mint(address,uint256)"));
        dad.permit(address(Governanceemissions), address(esBCKGOV), S("burn(address,uint256)"));

        dad.permit(address(buysBCKGOV), address(BCKGOV), S("mint(address,uint256)"));
        dad.permit(address(buysBCKGOV), address(BCKGOV), S("burn(address,uint256)"));

        dad.permit(address(buyseUSD), address(stabletoken), S("mint(address,uint256)"));
        dad.permit(address(buyseUSD), address(stabletoken), S("burn(address,uint256)"));

        dad.setOwner(owner);
        step += 1;
    }
    
}
