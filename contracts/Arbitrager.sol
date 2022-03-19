pragma solidity 0.5.6;

import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IKIP7.sol";
import "./interfaces/IKlaySwapProtocol.sol";
import "./interfaces/IClaimSwapRouter.sol";
import "./interfaces/IKlaySwapExchange.sol";

contract Arbitrager {

    ILendingPool LENDING_POOL;
    IKlaySwapProtocol KLAYSWAP;
    IClaimSwapRouter CLAIMSWAP;

    mapping(address => mapping(address => bool)) approvedTokens;
    address ArbitragerClaimToKlaySwap;
    address ArbitragerKlaySwapToClaim;

    function swapKlaySwapToClaimSwap(address tokenA, address tokenB, uint256 amount) public {
        address[] memory assets = new address[](1);
        assets[0] = tokenA;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory params = addressToBytes(tokenB);

        LENDING_POOL.flashLoan(
            ArbitragerKlaySwapToClaim,
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    function swapClaimSwapToKlaySwap(address tokenA, address tokenB, uint256 amount) public {
        address[] memory assets = new address[](1);
        assets[0] = tokenA;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory params = addressToBytes(tokenB);

        LENDING_POOL.flashLoan(
            ArbitragerClaimToKlaySwap,
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );

    }

    function addressToBytes(address a) public pure returns (bytes memory) {
        return abi.encodePacked(a);
    }
}
