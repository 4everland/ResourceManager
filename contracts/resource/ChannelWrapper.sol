// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

abstract contract ChannelWrapper is Ownable {
	address public channel;

	event SetChildChannel(address indexed childChannel);

	constructor(address childChannel) {
		channel = childChannel;
		emit SetChildChannel(address(childChannel));
	}

	function transferChildChannel(address _channel) external onlyOwner {
		channel = _channel;
	}

	modifier onlyChannel() {
		require(msg.sender == address(channel), 'ChannelWrapper: Can be called by channel only.');
		_;
	}
}
