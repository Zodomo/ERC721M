//// ERC721M.sol

interface IFactory {
    function ownershipUpdate(address _newOwner) external;
}

// NOTE: Must set factory address if factory is to be notified of ownership changes
address public constant factory = address(0);

// Ownership change overrides to callback into factory to notify frontend
function transferOwnership(address _newOwner) public payable override onlyOwner {
    address _factory = factory;
    if (_factory != address(0)) { IFactory(_factory).ownershipUpdate(_newOwner); }
    super.transferOwnership(_newOwner);
}
function renounceOwnership() public payable override onlyOwner {
    address _factory = factory;
    if (_factory != address(0)) { IFactory(_factory).ownershipUpdate(address(0)); }
    super.renounceOwnership();
}

//// ERC721MFactory.sol

modifier onlyCollection(address _collection) {
    if (contractDeployers[_collection] == address(0)) { revert NotDeployed(); }
    _;
}

function ownershipUpdate(address _newOwner) external onlyCollection(msg.sender) {
    emit OwnershipChanged(msg.sender, _newOwner);
}