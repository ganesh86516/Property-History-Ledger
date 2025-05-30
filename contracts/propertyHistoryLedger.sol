// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Property History Ledger
 * @dev A smart contract to track property ownership and transaction history
 */
contract PropertyHistoryLedger {
    
    // Structure to store property information
    struct Property {
        uint256 propertyId;
        string propertyAddress;
        string description;
        address currentOwner;
        uint256 currentValue;
        uint256 registrationDate;
        bool isActive;
    }
    
    // Structure to store transaction history
    struct Transaction {
        uint256 transactionId;
        uint256 propertyId;
        address previousOwner;
        address newOwner;
        uint256 transactionValue;
        uint256 timestamp;
        string transactionType; // "registration", "sale", "transfer"
    }
    
    // State variables
    mapping(uint256 => Property) public properties;
    mapping(uint256 => Transaction[]) public propertyTransactions;
    mapping(address => uint256[]) public ownerProperties;
    
    uint256 public propertyCounter;
    uint256 public transactionCounter;
    address public contractOwner;
    
    // Events
    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed previousOwner, address indexed newOwner, uint256 value);
    event PropertyValueUpdated(uint256 indexed propertyId, uint256 oldValue, uint256 newValue);
    
    // Modifiers
    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }
    
    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].currentOwner == msg.sender, "Only property owner can perform this action");
        _;
    }
    
    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isActive, "Property does not exist or is inactive");
        _;
    }
    
    constructor() {
        contractOwner = msg.sender;
        propertyCounter = 0;
        transactionCounter = 0;
    }
    
    /**
     * @dev Register a new property in the ledger
     * @param _propertyAddress Physical address of the property
     * @param _description Description of the property
     * @param _initialValue Initial value of the property in wei
     */
    function registerProperty(
        string memory _propertyAddress,
        string memory _description,
        uint256 _initialValue
    ) external returns (uint256) {
        propertyCounter++;
        uint256 newPropertyId = propertyCounter;
        
        // Create new property
        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            description: _description,
            currentOwner: msg.sender,
            currentValue: _initialValue,
            registrationDate: block.timestamp,
            isActive: true
        });
        
        // Add to owner's property list
        ownerProperties[msg.sender].push(newPropertyId);
        
        // Record transaction
        transactionCounter++;
        propertyTransactions[newPropertyId].push(Transaction({
            transactionId: transactionCounter,
            propertyId: newPropertyId,
            previousOwner: address(0),
            newOwner: msg.sender,
            transactionValue: _initialValue,
            timestamp: block.timestamp,
            transactionType: "registration"
        }));
        
        emit PropertyRegistered(newPropertyId, msg.sender, _propertyAddress);
        
        return newPropertyId;
    }
    
    /**
     * @dev Transfer property ownership from current owner to new owner
     * @param _propertyId ID of the property to transfer
     * @param _newOwner Address of the new owner
     * @param _transactionValue Value of the transaction in wei
     */
    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transactionValue
    ) external propertyExists(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");
        
        address previousOwner = properties[_propertyId].currentOwner;
        
        // Update property owner and value
        properties[_propertyId].currentOwner = _newOwner;
        properties[_propertyId].currentValue = _transactionValue;
        
        // Remove from previous owner's list
        _removePropertyFromOwner(previousOwner, _propertyId);
        
        // Add to new owner's list
        ownerProperties[_newOwner].push(_propertyId);
        
        // Record transaction
        transactionCounter++;
        propertyTransactions[_propertyId].push(Transaction({
            transactionId: transactionCounter,
            propertyId: _propertyId,
            previousOwner: previousOwner,
            newOwner: _newOwner,
            transactionValue: _transactionValue,
            timestamp: block.timestamp,
            transactionType: "transfer"
        }));
        
        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, _transactionValue);
    }
    
    /**
     * @dev Get complete transaction history for a property
     * @param _propertyId ID of the property
     * @return Array of transactions for the property
     */
    function getPropertyHistory(uint256 _propertyId) 
        external 
        view 
        propertyExists(_propertyId) 
        returns (Transaction[] memory) {
        return propertyTransactions[_propertyId];
    }
    
    /**
     * @dev Get all properties owned by a specific address
     * @param _owner Address of the property owner
     * @return Array of property IDs owned by the address
     */
    function getPropertiesByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }
    
    /**
     * @dev Get property details by ID
     * @param _propertyId ID of the property
     * @return Property struct containing all property details
     */
    function getPropertyDetails(uint256 _propertyId) 
        external 
        view 
        propertyExists(_propertyId) 
        returns (Property memory) {
        return properties[_propertyId];
    }
    
    /**
     * @dev Update property value (only by property owner)
     * @param _propertyId ID of the property
     * @param _newValue New value of the property
     */
    function updatePropertyValue(uint256 _propertyId, uint256 _newValue) 
        external 
        propertyExists(_propertyId) 
        onlyPropertyOwner(_propertyId) {
        uint256 oldValue = properties[_propertyId].currentValue;
        properties[_propertyId].currentValue = _newValue;
        
        emit PropertyValueUpdated(_propertyId, oldValue, _newValue);
    }
    
    /**
     * @dev Internal function to remove property from owner's list
     * @param _owner Address of the owner
     * @param _propertyId ID of the property to remove
     */
    function _removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
    
    /**
     * @dev Get total number of registered properties
     * @return Total count of properties
     */
    function getTotalProperties() external view returns (uint256) {
        return propertyCounter;
    }
    
    /**
     * @dev Get total number of transactions
     * @return Total count of transactions
     */
    function getTotalTransactions() external view returns (uint256) {
        return transactionCounter;
    }
}
