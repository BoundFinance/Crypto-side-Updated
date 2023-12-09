pragma solidity ^0.8.19;

import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/note.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/esBCKGOVemissions.sol";


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




contract StablecointoBCK is DSAuth, DSNote {
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    // Existing variables and events
    IERC20 public stableToken;
    BCK public bck;
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


    event Deposited(address indexed user, uint256 amount);
    event ExcessConverted(uint256 stableAmount);
    event DistributedToReserve(uint time, uint256 amount);
    event Distributed(uint256 amount);
    event Exited(address indexed user, uint256 amount);
    event BCKMinted(address indexed user, uint256 amount);
    event BCKBurned(address indexed user, uint256 amount);
    emissions public emmission; 
    global public globals;
    cashbackcontract public cash;

    constructor(address _erc20Address, address _bck, address _cashback, address _protocol)  {
        stableToken = IERC20(_erc20Address);
        bck = BCK(_bck);
        cashbackapp = _cashback;
        protocol = _protocol;
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

    function setratios (uint amount, uint sharetoprotocol, uint reserveamount) public auth {
        ratiostablebck = amount / 1000; // ratio to convert to stablecoin BCK
        ratiotoconvertback = 1000 / amount; // ratio to convert BCK back to stablecoin
        protocolshareofexcess = sharetoprotocol / 100; // protcol shares of yield, the rest goes to cashbackapp
        reserveamountpercentage = reserveamount; // amount of APY left to users compared to Protocol & Cashback
    }

    function share(address _user) public view returns (uint256) {
        return shares[_user];
    }

    function totaldeposits() public view returns (uint256) {
        return totalDepositedAsset;
    }

function depositsStable(uint256 amount) public payable note {
        distribute();
        require(stableToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(stableToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        address user = msg.sender;

        totalDepositedAsset += amount;
       
      //global shares - collateral amount and global balance - total number of $BCK minted.
        shares[msg.sender] += amount;
        
        globals.globalsharesadd(user, amount); 
        globals.globaltotaldepositadd(amount);

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .sub((magnifiedExcessPerShare.mul(amount)).toInt256Safe());
    
        emmission.updateInterestCorrectionssub(user, amount);
        
        emit Deposited(msg.sender, amount);
    }

  


function exitStable(uint amount) public payable note {
        distribute();
        uint256 maxWithdrawable = (((shares[msg.sender] / 2) - balance[msg.sender]) * 2);
        address user = msg.sender;
        require(amount <= maxWithdrawable, "Withdrawal exceeds collateral limit");
        require(shares[msg.sender] >= amount, "You don't have enough shares to withdraw this amount");
        require(stableToken.balanceOf(address(this)) >= amount, "you have insufficient balance");
        

        totalDepositedAsset -= (amount);
       
        shares[msg.sender] -= (amount);
        
        globals.globalsharessub(user, amount); 
        globals.globaltotaldepositsub(amount);

        magnifiedExcessCorrections[msg.sender] = magnifiedExcessCorrections[msg.sender]
            .add((magnifiedExcessPerShare.mul(amount)).toInt256Safe());

        emmission.updateInterestCorrectionsadd(user, amount);
        require(stableToken.transferFrom(address(this), msg.sender, amount), "The transfer failed");
        emit Exited(msg.sender, amount);
    }


        // Function to mint BCK tokens
    function mintBCK(uint256 amount) public payable note {
        uint256 maxmint = (shares[msg.sender] / 2) - balance[msg.sender];
        require(amount <= maxmint, "Exceeds collateral ratio limit");
        address user = msg.sender;

        balance[msg.sender] += (amount);
        globals.globalbalanceadd(user, amount);
        bck.mint(msg.sender, amount);
    
        emit BCKMinted(msg.sender, amount);
    }

    function maxMintvalue(address _user) public view returns (uint) {
        uint256 maxmint = ((shares[_user].div(2)) - balance[_user]);
        return maxmint;
    }

  function withdrawMaxStable(address _user) public view returns (uint) {
         uint256 maxWithdrawable = (((shares[_user].div(2)) - balance[_user]).mul(2));
         return maxWithdrawable;
    }

    // Function to burn BCK tokens
    function burnBCK(uint256 amount) public payable note {
        require(balance[msg.sender] >= amount, "No burn allowance");
        require(bck.balanceOf(msg.sender) >= amount, "Insufficient BCK balance");
        address user = msg.sender;

        balance[msg.sender] -= amount;
        globals.globalbalancesub(user, amount);
        bck.burn(msg.sender, amount);
    
        emit BCKBurned(msg.sender, amount);
    }

//calculate the rebased interest of LSDfi stablecoins
function convertExcess() internal  {
        uint256 excessAmount = stableToken.balanceOf(address(this)) - (totalDepositedAsset);
        require(excessAmount >= 0, "excess much be greater than 0");
        if(excessAmount == 0) {
            return;
        }

        uint256 amountForConversion = excessAmount - totalExcessReserve;
        if(amountForConversion == 0) {
            return;
        }
        // Reserve 20% for the users
        uint256 reserveForUsers = (amountForConversion * reserveamountpercentage) / 100;

        totalExcessReserve += reserveForUsers;
        emit DistributedToReserve(block.timestamp, reserveForUsers);

        if (totalDepositedAsset > 0) {
            magnifiedExcessPerShare = magnifiedExcessPerShare.add(
                (reserveForUsers).mul(magnitude).div(totalDepositedAsset)
            );
        }

        uint amountForConversion1 = amountForConversion - reserveForUsers;
        uint cashbackappreward = amountForConversion1 * ((100 - protocolshareofexcess) / 100);
        cashbackappshare += cashbackappreward;
        uint protocolreward = amountForConversion1 - cashbackappreward;
        // this function will be used in mainnet //cash.depositUSDC(cashbackappreward);
        stableToken.transferFrom(address(this), address(cashbackapp), cashbackappreward);
        stableToken.transferFrom(address(this), address(protocol), protocolreward);
        emit Distributed(cashbackappreward);     
    }

// WithdrawExcess - used to withdraw the excess funds from the users.
function withdrawExcess() public {
        distribute();
        uint256 _withdrawableExcess = withdrawableExcessOf(msg.sender);
        
        if (_withdrawableExcess > 0) {
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
