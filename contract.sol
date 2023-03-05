// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract Multi_Signature_wallet {
    event Deposit(address indexed sender, uint amount); 
    event Submit(uint indexed txID);
    event Approve(address indexed owner, uint indexed txID);
    event Revoke(address indexed owner, uint indexed txID);
    event Execute(uint indexed txID);

    struct Transaction{ // to store the detail of the trasaction 
        address to; // to adress where the transaction is being sent
        uint value; // value being sent 
        bytes data; // if data being sent along with transaction 
        bool isExecuted; // boolean to check if the transaction got approved by the majority owners and executed
    }

    address[] public owners; // array of the owners 
    mapping(address => bool) public isOwner; // to check if msg.sender is the owner
    uint public requiredApprovals; // to make sure a minimum amount of owner approvals to execute transaction

    Transaction[] public transactions; // to create an array of the transactions 
    mapping(uint => mapping(address => bool)) public approved; // to check transaction had which owner approve them 

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Only the owner can call the function");
        _;
    }

    modifier txExists(uint _txID) {
        require(_txID < transactions.length,"The transaction doesn't exist");
        _;
    }

    modifier notApproved(uint _txID) {
        require(!approved[_txID][msg.sender],"the transaction is already approved");
        _;
    }

    modifier notExecuted(uint _txID) {
        require(!transactions[_txID].isExecuted,"The transaction is already executed");
        _;
    }

    constructor(address[] memory _owners, uint required){
        require(_owners.length > 0, "no owners given");
        require(required > 0 && required <= _owners.length, "Invalid number of owners ");

        for(uint i;i < _owners.length; i++) {
            address owner = _owners[i];
            require(!isOwner[owner],"The owner is not unique"); // to check with mapping if owner is unique
            require(owner != address(0),"invalid owner");
            isOwner[owner] = true; // address in the mapping is being added as the owner 
            owners.push(owner); // addresses of the owners being stored in the array 
        }

        requiredApprovals = required; // number of approvals needed for the transaction to get approved
    }

    receive() external payable {
        emit Deposit(msg.sender,msg.value);
    }


    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            isExecuted: false
        }));
        // Transaction memory transaction; // my method of doing the same above thing 
        // transaction.to = _to;
        // transaction.value = _value;
        // transaction.data = _data;
        // transaction.isExecuted = false;
        // transactions.push(transaction);

        emit Submit(transactions.length - 1);
    }

    function approve(uint _txID) external onlyOwner txExists(_txID) notApproved(_txID) notExecuted(_txID) {
        approved[_txID][msg.sender] = true;
        emit Approve(msg.sender, _txID);
    }
 
    // specifying returns type with var name will help save gas as it initiated outside a function 
    // and also we dont need to explicitely type return at the end of the function to return the var 
    function _getApprovalcount(uint _txID) private view returns(uint count) { 
        for(uint i; i< owners.length ; i++){
            if (approved[_txID][owners[i]]) {
                count++;
            }
        }
    }

    function execute(uint _txID) external txExists(_txID) notExecuted(_txID) {
        require(_getApprovalcount(_txID) >= requiredApprovals, "the tx has not been approved by the required num of ppl");
        Transaction storage transaction = transactions[_txID];
        transaction.isExecuted = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
    
        require(success, "tx has failed");

        emit Execute(_txID);
    }

    function revoke(uint _txID) external onlyOwner txExists(_txID) notExecuted(_txID) {
        require(approved[_txID][msg.sender],"tx has not been approved by u");
        approved[_txID][msg.sender] = false;

        emit Revoke(msg.sender,_txID);
    }
}
