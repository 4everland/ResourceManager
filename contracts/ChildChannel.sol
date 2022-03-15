// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Address.sol';

interface MessageProcessor {
	function processMessageFromRoot(
		uint256 stateId,
		address rootMessageSender,
		bytes calldata data
	) external;
}

/**
 * @notice Mock child tunnel contract to receive and send message from L2
 */
contract ChildChannel is  MessageProcessor, Ownable {
	using Address for address;

	address public child;

	// root channel => receiver
	mapping(address => address) public channelReceivers;

	event SetRootChannel(address channel, address receiver);
	event MessageSent(bytes message);
	event MessageReceived(uint256 indexed stateId, address indexed sender, bytes message, string error);
	// Matic testnnet 0xCf73231F28B7331BBe3124B907840A94851f9f11
	// Matic mainnet 0x8397259c983751DAf40400790063935a11afa28a

	constructor(address _child, address _master) {
		child = _child;
		transferOwnership(_master);
	}

	// Sender must be rootChannel in case of ERC20 tunnel
	modifier validateSender(address sender) {
		require(channelReceivers[sender] != address(0), 'ChildChannel: INVALID_SENDER_FROM_ROOT');
		_;
	}

	// set rootChannel if not set already
	function setRootChannel(address _rootChannel, address receiver) external onlyOwner {
		require(_rootChannel != address(0), 'ChildChannel: Invalid channel.');
		require(receiver != address(0), 'ChildChannel: Invalid receiver.');
		channelReceivers[_rootChannel] = receiver;
		emit SetRootChannel(_rootChannel, receiver);
	}

	function processMessageFromRoot(
		uint256 stateId,
		address rootMessageSender,
		bytes calldata data
	) public override {
		require(msg.sender == child, 'ChildChannel: INVALID_SENDER');
		_processMessageFromRoot(stateId, rootMessageSender, data);
	}

	/**
	 * @notice Emit message that can be received on Root Tunnel
	 * @dev Call the internal function when need to emit message
	 * @param message bytes message that will be sent to Root Tunnel
	 * some message examples -
	 *   abi.encode(tokenId);
	 *   abi.encode(tokenId, tokenMetadata);
	 *   abi.encode(messageType, messageData);
	 */
	function sendMessageToRoot(bytes memory message) external onlyOwner {
		emit MessageSent(message);
	}

	/**
	 * @notice Process message received from Root Tunnel
	 * @dev function needs to be implemented to handle message as per requirement
	 * This is called by onStateReceive function.
	 * Since it is called via a system call, any event will not be emitted during its execution.
	 * @param stateId unique state id
	 * @param sender root message sender
	 * @param message bytes message that was sent from Root Tunnel
	 */
	function _processMessageFromRoot(
		uint256 stateId,
		address sender,
		bytes memory message
	) internal validateSender(sender) {
		address receiver = channelReceivers[sender];
		require(receiver != address(0), 'ChildChannel: Invalid receiver');
		(bool success, bytes memory returndata) = receiver.call(message);
		if (!success) {
			emit MessageReceived(stateId, sender, message, abi.decode(returndata,(string)));
		} else {
			emit MessageReceived(stateId, sender, message, '');
		}
	}

}
