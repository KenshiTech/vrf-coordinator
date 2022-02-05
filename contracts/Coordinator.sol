//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "./interfaces/IBEP1363Spender.sol";

/**
 * Note: no need to import the entire IBEP20 when these are the only
 * functions we need.
 */
interface IToken {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

/**
 * Note: no need to import the entire IBEP20 when these are the only
 * functions we need.
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

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() {}

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Coordinator is Context, Ownable, IBEP1363Spender {
    mapping(address => mapping(uint256 => bool)) private _fulfilled;
    mapping(address => bool) private _oracleAddrs;

    uint256 private _price;
    uint256 private _minApproval;
    address private _kenshiAddr;
    address private _collectorAddr;

    constructor() {}

    function getPrice() external view returns (uint256) {
        return _price;
    }

    function setPrice(uint256 price) external onlyOwner {
        _price = price;
    }

    function getMinApproval() external view returns (uint256) {
        return _minApproval;
    }

    function setMinApproval(uint256 min) external onlyOwner {
        _minApproval = min;
    }

    function getCollectorAddr() external view returns (address) {
        return _collectorAddr;
    }

    function setCollectorAddr(address collector) external onlyOwner {
        _collectorAddr = collector;
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
    function isAdmin(address addr) external view returns (bool) {
        return _oracleAddrs[addr];
    }

    /**
     * @dev Set `addr` is excluded from reflections to `state`.
     */
    function setIsAdmin(address addr, bool state) external onlyOwner {
        _oracleAddrs[addr] = state;
    }

    event RandomnessRequested(address requester, uint256 requestId);

    function onApprovalReceived(
        address owner,
        uint256 value,
        bytes memory data
    ) external returns (bytes4) {
        require(
            _msgSender() == address(_kenshiAddr),
            "Coordinator: Message sender is not the Kenshi token"
        );

        require(
            value >= _minApproval,
            "Coordinator: Transferred amount is lower than the current price"
        );

        uint256 requestId = abi.decode(data, (uint256));

        emit RandomnessRequested(owner, requestId);

        return IBEP1363Spender(this).onApprovalReceived.selector;
    }

    function fullfillRandomnessForContract(
        address requester,
        uint256 requestId,
        uint256[4] memory proof,
        bytes memory message,
        uint256[2] memory uPoint,
        uint256[4] memory vComponents,
        uint256 kenshisPerWei
    ) external onlyOracles {
        uint256 gasAtStart = gasleft();
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
        uint256 gasSpent = gasAtStart - gasleft();
        uint256 gasPriceInKenshi = gasSpent * kenshisPerWei;
        uint256 totalPrice = gasPriceInKenshi +
            ((gasPriceInKenshi * 10) / 100) +
            _price;
        bool transferred = IToken(_kenshiAddr).transferFrom(
            requester,
            _collectorAddr,
            totalPrice
        );
        require(transferred, "Coordinator: Transfer from failed");
    }
}
