//SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.11;

import "./interfaces/IVRFConsumer.sol";
import "./libraries/Ownable.sol";

contract Coordinator is Context, Ownable {
    mapping(address => mapping(uint256 => bool)) private _fulfilled;
    mapping(address => uint256) _requestIds;
    mapping(address => bool) private _oracleAddrs;

    address private _vrfUtilsAddr;

    constructor() {}

    function getVrfUtilsAddr() external view returns (address) {
        return _vrfUtilsAddr;
    }

    function setVrfUtilsAddr(address vrfUtilsAddr) external onlyOwner {
        _vrfUtilsAddr = vrfUtilsAddr;
    }

    /**
     * @dev Throws if called by any account other than the oracles.
     */
    modifier onlyOracles() {
        require(
            _oracleAddrs[_msgSender()],
            "Coordinator: Caller is not an oracle"
        );
        _;
    }

    /**
     * @dev Check if `addr` is an oracle.
     */
    function isOracle(address addr) external view returns (bool) {
        return _oracleAddrs[addr];
    }

    /**
     * @dev Set if `addr` is an oracle.
     */
    function setIsOracle(address addr, bool state) external onlyOwner {
        _oracleAddrs[addr] = state;
    }

    event RandomnessRequested(address requester, uint256 requestId);

    function requestRandomness() external returns (uint256) {
        uint256 requestId = _requestIds[_msgSender()]++;
        emit RandomnessRequested(_msgSender(), requestId);
        return requestId;
    }

    function fullfillRandomnessForContract(
        address requester,
        uint256 requestId,
        uint256[4] memory proof,
        bytes memory message,
        uint256[2] memory uPoint,
        uint256[4] memory vComponents
    ) external onlyOracles {
        require(
            !_fulfilled[requester][requestId],
            "Coordinator: Already fulfilled"
        );

        IVRFConsumer consumer = IVRFConsumer(requester);
        consumer.onRandomnessReady(
            proof,
            message,
            uPoint,
            vComponents,
            requestId
        );

        _fulfilled[requester][requestId] = true;
    }
}
