//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

/**
 * Note: `onRandomnessReady` is the only function we need
 */
interface IVRFConsumer {
    function onRandomnessReady(
        uint256[4] memory _proof,
        bytes memory _message,
        uint256[2] memory _uPoint,
        uint256[4] memory _vComponents,
        uint256 requestId
    ) external;
}
