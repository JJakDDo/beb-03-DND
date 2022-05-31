// SPDX-License-Identifier: MIT
pragma solidity ^0.5.6;

interface IDNDCallee {
    function DNDCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
