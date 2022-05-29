pragma solidity 0.5.6;

import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IKlaySwapProtocol.sol";
import "./interfaces/IClaimSwapRouter.sol";
import "./interfaces/IKlaySwapExchange.sol";
import "./interfaces/IKIP7.sol";

contract ArbitragerKlaySwapToClaim is IFlashLoanReceiver {
    ILendingPool LENDING_POOL;
    IKlaySwapProtocol KLAYSWAP;
    IClaimSwapRouter CLAIMSWAP;
    mapping(address => mapping(address => bool)) approvedTokens;

    struct OperationData {
        uint klaySwapEstimateOut;
        uint claimSwapEstimateOut;
        uint assetLength;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool){
        OperationData memory opData;
        address[] memory path = new address[](2);
        // tokenB
        path[0] = bytesToAddress(params);
        // tokenA
        path[1] = assets[0];

        IKlaySwapExchange klaySwapPool = IKlaySwapExchange(KLAYSWAP.tokenToPool(path[0], path[1]));
        opData.klaySwapEstimateOut = klaySwapPool.estimatePos(path[1], amounts[0]);
        opData.claimSwapEstimateOut = CLAIMSWAP.getAmountsOut(opData.klaySwapEstimateOut, path)[1];
        require(opData.claimSwapEstimateOut > amounts[0]);

        _swapKlaySwap(path[1], path[0], amounts[0]);
        _swapClaimSwap(path[0], path[1], opData.klaySwapEstimateOut);

        opData.assetLength = assets.length;
        for (uint i = 0; i < opData.assetLength; i++) {
            checkApprove(assets[i], address(LENDING_POOL));
        }
        IKIP7(assets[opData.assetLength]).transfer(msg.sender, opData.claimSwapEstimateOut - amounts[0] - premiums[0]);
        return true;
    }


    function _swapKlaySwap(address tokenA, address tokenB, uint256 amount) private {
        checkApprove(tokenA, address(KLAYSWAP));
        KLAYSWAP.exchangeKctPos(tokenA, amount, tokenB, 10, new address[](0));
    }

    function _swapClaimSwap(address tokenA, address tokenB, uint256 amount) private {
        checkApprove(tokenA, address(CLAIMSWAP));
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        CLAIMSWAP.swapExactTokensForTokens(amount, 10, path, address(this), 4230424911);
    }

    function checkApprove(address token, address spender) public {
        if (token == address(0x0000000000000000000000000000000000000000)) {
            return;
        }
        if (!approvedTokens[spender][token]) {
            IKIP7(token).approve(spender, uint(2 ** 256 - 1));
            approvedTokens[spender][token] = true;
        }
    }

    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}
