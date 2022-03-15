// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

interface IServiceStorageManager {

	function accountExists(bytes32 to) external view returns (bool);
	
	function total(bytes32 to) external returns(uint256);

	function cost(bytes32 to) external returns(uint256);

	function left(bytes32 to) external returns(uint256);

	function expiration(bytes32 to) external returns(uint256);

	function guid(bytes2 gId, bytes2 serviceId, bytes28 uuid) external pure returns (bytes32);

	function syncStorage(
		bytes2 gId, 
		bytes2 serviceId, 
		bytes28 uuid,
		uint256 amount,
		uint256 expiration_
	) external;

	event SyncStorage(bytes32 indexed to, uint256 amount, uint256 expiration);

}