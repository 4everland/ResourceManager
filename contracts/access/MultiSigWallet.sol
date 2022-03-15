// SPDX-License-Identifier: UNLICENSE

pragma solidity >=0.8.0;

/// @title Multisignature wallet - Allows multiple parties to agree on transactions before execution.
/// @author Stefan George - <stefan.george@consensys.net>
contract MultiSigWallet {
	/*
	 *  Events
	 */
	event Confirmation(address indexed sender, uint256 indexed transactionId);
	event Revocation(address indexed sender, uint256 indexed transactionId);
	event Submission(uint256 indexed transactionId);
	event Execution(uint256 indexed transactionId);
	event ExecutionFailure(uint256 indexed transactionId);
	event Deposit(address indexed sender, uint256 value);
	event OwnerAddition(address indexed owner);
	event OwnerRemoval(address indexed owner);
	event RequirementChange(uint256 required);

	/*
	 *  Constants
	 */
	uint256 public constant MAX_OWNER_COUNT = 50;

	/*
	 *  Storage
	 */
	mapping(uint256 => Transaction) public transactions;
	mapping(uint256 => mapping(address => bool)) public confirmations;
	mapping(address => bool) public isOwner;
	address[] public owners;
	uint256 public required;
	uint256 public transactionCount;

	struct Transaction {
		address destination;
		uint256 value;
		bytes data;
		bool executed;
	}

	/*
	 *  Modifiers
	 */
	modifier onlyWallet() {
		require(msg.sender == address(this), 'MultiSigWallet: not wallet.');
		_;
	}

	modifier ownerDoesNotExist(address owner) {
		require(!isOwner[owner], 'MultiSigWallet: owner exists.');
		_;
	}

	modifier ownerExists(address owner) {
		require(isOwner[owner], 'MultiSigWallet: owner nonexistent.');
		_;
	}

	modifier transactionExists(uint256 transactionId) {
		require(transactions[transactionId].destination != address(0), 'MultiSigWallet: transaction nonexistent.');
		_;
	}

	modifier confirmed(uint256 transactionId, address owner) {
		require(confirmations[transactionId][owner], 'MultiSigWallet: transaction not confirmed.');
		_;
	}

	modifier notConfirmed(uint256 transactionId, address owner) {
		require(!confirmations[transactionId][owner], 'MultiSigWallet: transaction confirmed.');
		_;
	}

	modifier notExecuted(uint256 transactionId) {
		require(!transactions[transactionId].executed, 'MultiSigWallet: transaction executed.');
		_;
	}

	modifier notNull(address _address) {
		require(_address != address(0), 'MultiSigWallet: address zero.');
		_;
	}

	modifier validRequirement(uint256 ownerCount, uint256 _required) {
		require(ownerCount <= MAX_OWNER_COUNT && _required <= ownerCount && _required != 0 && ownerCount != 0, 'MultiSigWallet: invalid requirement.');
		_;
	}

	/// @dev Fallback function allows to deposit ether.
	receive() external payable {
		if (msg.value > 0) emit Deposit(msg.sender, msg.value);
	}

	/*
	 * Public functions
	 */
	/// @dev Contract constructor sets initial owners and required number of confirmations.
	/// @param _owners List of initial owners.
	/// @param _required Number of required confirmations.
	constructor(address[] memory _owners, uint256 _required) validRequirement(_owners.length, _required) {
		for (uint256 i = 0; i < _owners.length; i++) {
			require(!isOwner[_owners[i]] && _owners[i] != address(0), 'MultiSigWallet: owner exsits.');
			isOwner[_owners[i]] = true;
		}
		owners = _owners;
		required = _required;
	}

	/// @dev Allows to add a new owner. Transaction has to be sent by wallet.
	/// @param owner Address of new owner.
	function addOwner(address owner) public onlyWallet ownerDoesNotExist(owner) notNull(owner) validRequirement(owners.length + 1, required) {
		isOwner[owner] = true;
		owners.push(owner);
		emit OwnerAddition(owner);
	}

	/// @dev Allows to remove an owner. Transaction has to be sent by wallet.
	/// @param owner Address of owner.
	function removeOwner(address owner) public onlyWallet ownerExists(owner) {
		for (uint256 i = 0; i < owners.length - 1; i++)
			if (owners[i] == owner) {
				delete owners[i];
				delete isOwner[owner];
				break;
			}
		if (required > owners.length) changeRequirement(owners.length);
		emit OwnerRemoval(owner);
	}

	/// @dev Allows to replace an owner with a new owner. Transaction has to be sent by wallet.
	/// @param owner Address of owner to be replaced.
	/// @param newOwner Address of new owner.
	function replaceOwner(address owner, address newOwner) public onlyWallet ownerExists(owner) ownerDoesNotExist(newOwner) {
		for (uint256 i = 0; i < owners.length; i++)
			if (owners[i] == owner) {
				owners[i] = newOwner;
				break;
			}
		isOwner[owner] = false;
		isOwner[newOwner] = true;
		emit OwnerRemoval(owner);
		emit OwnerAddition(newOwner);
	}

	/// @dev Allows to change the number of required confirmations. Transaction has to be sent by wallet.
	/// @param _required Number of required confirmations.
	function changeRequirement(uint256 _required) public onlyWallet validRequirement(owners.length, _required) {
		required = _required;
		emit RequirementChange(_required);
	}

	function submitTransaction(
		address destination,
		uint256 value,
		bytes memory data
	) public returns (uint256 transactionId) {
		transactionId = addTransaction(destination, value, data);
		confirmTransaction(transactionId);
	}

	/// @dev Allows an owner to confirm a transaction.
	/// @param transactionId Transaction ID.
	function confirmTransaction(uint256 transactionId) public ownerExists(msg.sender) transactionExists(transactionId) notConfirmed(transactionId, msg.sender) {
		confirmations[transactionId][msg.sender] = true;
		emit Confirmation(msg.sender, transactionId);
		executeTransaction(transactionId);
	}

	/// @dev Allows an owner to revoke a confirmation for a transaction.
	/// @param transactionId Transaction ID.
	function revokeConfirmation(uint256 transactionId) public ownerExists(msg.sender) confirmed(transactionId, msg.sender) notExecuted(transactionId) {
		confirmations[transactionId][msg.sender] = false;
		emit Revocation(msg.sender, transactionId);
	}

	/// @dev Allows anyone to execute a confirmed transaction.
	/// @param transactionId Transaction ID.
	function executeTransaction(uint256 transactionId) public ownerExists(msg.sender) confirmed(transactionId, msg.sender) notExecuted(transactionId) {
		if (isConfirmed(transactionId)) {
			Transaction storage txn = transactions[transactionId];
			txn.executed = true;

			if (external_call(txn.destination, txn.value, txn.data)) emit Execution(transactionId);
			else {
				emit ExecutionFailure(transactionId);
				txn.executed = false;
			}
		}
	}

	// call has been separated into its own function in order to take advantage
	// of the Solidity's code generator to produce a loop that copies tx.data into memory.
	function external_call(
		address destination,
		uint256 value,
		bytes memory data
	) internal returns (bool) {
		(bool success, bytes memory result) = destination.call{ value: value }(data);
		if (!success) revert(abi.decode(result, (string)));
		return success;
	}

	/// @dev Returns the confirmation status of a transaction.
	/// @param transactionId Transaction ID.
	/// @return Confirmation status.
	function isConfirmed(uint256 transactionId) public view returns (bool) {
		uint256 count = 0;
		for (uint256 i = 0; i < owners.length; i++) {
			if (confirmations[transactionId][owners[i]]) count += 1;
			if (count == required) return true;
		}
		return false;
	}

	function addTransaction(
		address destination,
		uint256 value,
		bytes memory data
	) internal notNull(destination) returns (uint256 transactionId) {
		transactionId = transactionCount;
		transactions[transactionId] = Transaction({ destination: destination, value: value, data: data, executed: false });
		transactionCount += 1;
		emit Submission(transactionId);
	}

	function getConfirmationCount(uint256 transactionId) public view returns (uint256 count) {
		for (uint256 i = 0; i < owners.length; i++) if (confirmations[transactionId][owners[i]]) count += 1;
	}

	function getTransactionCount(bool pending, bool executed) public view returns (uint256 count) {
		for (uint256 i = 0; i < transactionCount; i++) if ((pending && !transactions[i].executed) || (executed && transactions[i].executed)) count += 1;
	}

	/// @dev Returns list of owners.
	/// @return List of owner addresses.
	function getOwners() public view returns (address[] memory) {
		return owners;
	}

	function getConfirmations(uint256 transactionId) public view returns (address[] memory _confirmations) {
		address[] memory confirmationsTemp = new address[](owners.length);
		uint256 count = 0;
		uint256 i;
		for (i = 0; i < owners.length; i++)
			if (confirmations[transactionId][owners[i]]) {
				confirmationsTemp[count] = owners[i];
				count += 1;
			}
		_confirmations = new address[](count);
		for (i = 0; i < count; i++) _confirmations[i] = confirmationsTemp[i];
	}

	function getTransactionIds(
		uint256 from,
		uint256 to,
		bool pending,
		bool executed
	) public view returns (uint256[] memory _transactionIds) {
		uint256[] memory transactionIdsTemp = new uint256[](transactionCount);
		uint256 count = 0;
		uint256 i;
		for (i = 0; i < transactionCount; i++)
			if ((pending && !transactions[i].executed) || (executed && transactions[i].executed)) {
				transactionIdsTemp[count] = i;
				count += 1;
			}
		_transactionIds = new uint256[](to - from);
		for (i = from; i < to; i++) _transactionIds[i - from] = transactionIdsTemp[i];
	}
}
