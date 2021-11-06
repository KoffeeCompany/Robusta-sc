// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IPriceOracle {
    /**
     * @dev returns the asset price in ETH
     * @param asset the address of the asset
     * @return the ETH price of the asset
     **/
    function getAssetPrice(address asset) external view returns (uint256);
}
