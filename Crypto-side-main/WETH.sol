import "Crypto-side-main/ds-auth.sol";
import "Crypto-side-main/note.sol";
import "Crypto-side-main/SafemathInt2.sol";
import "Crypto-side-main/Safemathuint2.sol";
import "Crypto-side-main/esBCKGOVemissions.sol";
import "Crypto-side-main/interfaceParallax.sol";


contract WETH {
    IWETH weth;

    constructor(address _wethAddress) {
        weth = IWETH(_wethAddress);
    }


    function convertEthToWeth() external payable {
        require(msg.value > 0, "You need to send some Ether");
        weth.deposit{value: msg.value}();
    }

    function convertWethToEth(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        weth.withdraw(amount);
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send Ether");
    }
}

