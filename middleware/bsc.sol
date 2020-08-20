// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.7.0;
pragma experimental ABIEncoderV2;

/**
 * @title BSC
 * @dev Hold signatures and hashes of business process clauses
 */
contract BSC {
    ///// CONTRACT DATA /////

    struct Participant {
        //binding participants to their signature
        address pAddress;
        string signature;
    }

    struct Clause {
        string id;
        mapping(uint => Participant) participants;
        uint nbParticipants;
        ClauseState state;

        //When a clause is signed, it may change the state of the contract
        ContractState contractStateChange;
    }

    struct DataProof {
        string id;
        address oAddress;
        string dataHash;
        bool dataValid;
    }

    enum ContractState{AwaitingSignature, InExecution, Terminated, Completed, Litigation, Cancelled, None}
    enum ClauseState{Cancelled, Awaiting, Accepted}

    ContractState cState;
    //Memorizes the old state of the contract during litigation
    ContractState cOldState;
    address[] public participants;
    address[] public oracles;
    address[] public mediators;
    mapping(string => Clause) public clauses;
    mapping(string => DataProof) public dataProofs;
    string public slcHash;

    ///// CONTRACT EVENTS /////

    // event to inform parties about a contract state change
    event ContractStateChange(ContractState newState);

    // event to inform parties about a Clause update
    event ClauseStateChange(string id, ClauseState newState);

    // event to inform parties about an added clause
    event ClauseAdded(string id, address pAddress);

    // event to inform parties about new data proof on the contract
    event NewDataProof(string id, address oAddress);

    // event to inform parties about a deleted proof on the contract (by a mediator)
    event DataProofVoided(string id, address mAddress);

    // event to inform parties about the contract signature
    event SLCHashAdded(string slcHash, address pAddress);

    ///// CONTRACT MODIFIERS /////

    // modifier to check if caller is a participant
    modifier isParticipant() {
        bool found = false;
        for(uint i = 0; i < participants.length; i++) {
            if(participants[i] == msg.sender) {
                found = true;
            }
        }
        require(found, "The address provided is not part of the Participants list");
        _;
    }

    // modifier to check if caller is an oracle
    modifier isOracle() {
        bool found = false;
        for(uint i = 0; i < oracles.length; i++) {
            if(oracles[i] == msg.sender) {
                found = true;
            }
        }
        require(found, "The address provided is not part of the Oracles list");
        _;
    }

    // verify that the contract is not signed yet. Useful to let users add clauses before its signature.
    modifier contractNotSigned() {
        require(strHash(slcHash) == strHash(""), "Contract already signed");
        _;
    }

    // verify that the contract is signed.
    modifier contractSigned() {
        require(strHash(slcHash) != strHash(""), "Contract not signed");
        _;
    }

    // modifier to check if caller is a mediator
    modifier isMediator() {
        bool found = false;
        for(uint i = 0; i < mediators.length; i++) {
            if(mediators[i] == msg.sender) {
                found = true;
            }
        }
        require(found, "The address provided is not part of the Mediators list");
        _;
    }

    // ensures the clause exists
    modifier clauseExists(string memory cId) {
        if(strHash(clauses[cId].id) != strHash(cId)) {
            revert("The clause does not exist");
        }
        _;
    }

    // ensures the clause does not exist
    modifier clauseDoesNotExists(string memory cId) {
        if(strHash(clauses[cId].id) == strHash(cId)) {
            revert("The clause does exists");
        }
        _;
    }

    // ensures the data proof does not exist
    modifier dataProofDoesNotExists(string memory dId) {
        if(strHash(dataProofs[dId].id) == strHash(dId)) {
            revert("The data proof entry does not exist");
        }
        _;
    }

    // ensures the data proof exists
    modifier dataProofExists(string memory dId) {
        if(strHash(dataProofs[dId].id) != strHash(dId)) {
            revert("The data proof entry does exist");
        }
        _;
    }

    // ensures the clause is not cancelled
    modifier clauseNotCancelled(string memory cId) {
        if(clauses[cId].state == ClauseState.Cancelled) {
            revert("Clause is cancelled");
        }
        _;
    }

    // check the state of the contract
    modifier isInLitigation() {
        if(cState != ContractState.Litigation) {
            revert("Contract state is incorrect to perform this action");
        }
        _;
    }

    // check the state of the contract (negative)
    modifier isNotInLitigation() {
        if(cState == ContractState.Litigation) {
            revert("Contract state is incorrect to perform this action");
        }
        _;
    }

    // check if the contract execution is done, if so execution of functions are impossible
    modifier isNotFinished() {
        if(cState == ContractState.Terminated || cState == ContractState.Cancelled || cState == ContractState.Completed) {
            revert("Contract execution is completed, no further action can be performed");
        }
        _;
    }

    ///// CONTRACT FUNCTIONS /////

    // returns a hash of a string, used to compare them even between memory/storage values
    function strHash(string memory str) private pure returns(bytes32 ret) {
        return keccak256(abi.encodePacked(str));
    }

    function changeContractState(ContractState newState) private {
        cState = newState;
        emit ContractStateChange(newState);
    }

    function changeClauseState(string memory cId, ClauseState newState) private {
        clauses[cId].state = newState;
        emit ClauseStateChange(cId, newState);
    }

    //add a clause to the contract
    function addClause(string memory cId, address[] memory ps, ContractState cNewState) public contractNotSigned clauseDoesNotExists(cId) isParticipant isNotFinished {
        Clause memory c = Clause(cId, ps.length, ClauseState.Awaiting, cNewState);
        clauses[cId] = c;

        for(uint i = 0; i < ps.length; i++) {
            if(checkIfParticipantInContract(ps[i])) {
                Participant memory p = Participant(ps[i], "");
                clauses[cId].participants[i] = p;
            }
            else {
                revert("A participant provided in parameter is not listed in the contract");
            }
        }

        emit ClauseAdded(cId, msg.sender);
    }
    
    // check if a participant is correctly listed as a participant in the BSC
    function checkIfParticipantInContract(address pAddress) public view returns (bool ret) {
        for(uint i = 0; i < participants.length; i++) {
            if(pAddress == participants[i]) return true;
        }
        return false;
    }

    // check if a clause has been signed by all concerned participants
    function checkIfClauseIsSigned(string memory cId) public view clauseExists(cId) returns(bool ret) {
        bool isSigned = true;
        for(uint i = 0; i < clauses[cId].nbParticipants; i++) {
            if(strHash(clauses[cId].participants[i].signature) == strHash("")) {
                isSigned = false;
                return isSigned;
            }
        }
        return isSigned;
    }

    // add the SLC hash to the contract
    function addSlcHash(string memory _slcHash) public isParticipant contractNotSigned isNotFinished {
        slcHash = _slcHash;
        changeContractState(ContractState.InExecution);
        emit SLCHashAdded(slcHash, msg.sender);
    }

    // cancel the contract before its signature
    function cancelContract() public isMediator contractNotSigned isNotFinished {
        changeContractState(ContractState.Cancelled);
    }

    // terminate the contract if needed (mediator)
    function terminateContract() public isMediator contractSigned isInLitigation isNotFinished {
        changeContractState(ContractState.Terminated);
    }

    // complete the contract if needed (mediator)
    function completeContract() public isMediator contractSigned isInLitigation isNotFinished {
        changeContractState(ContractState.Completed);
    }

    // sign a clause
    function signClause(string memory cId, string memory signature) public clauseExists(cId) clauseNotCancelled(cId) isParticipant isNotInLitigation isNotFinished {
        for(uint i = 0; i < clauses[cId].nbParticipants; i++) {
            if(clauses[cId].participants[i].pAddress == msg.sender) {
                clauses[cId].participants[i].signature = signature;

                if(checkIfClauseIsSigned(cId)) {
                    changeClauseState(cId, ClauseState.Accepted);

                    if(clauses[cId].contractStateChange != ContractState.None) {
                        changeContractState(clauses[cId].contractStateChange);
                    }
                }

                return;
            }
        }

        revert("Message sender is not a clause participant");
    }

    // cancel a clause if needed (by mediator)
    function cancelClause(string memory cId) public clauseExists(cId) isMediator contractSigned isInLitigation isNotFinished {
        changeClauseState(cId, ClauseState.Cancelled);
    }

    // change contract state to litigation, block execution of normal functions
    function setContractInLitigation() public isMediator contractSigned isNotInLitigation isNotFinished {
        cOldState = cState;
        changeContractState(ContractState.Litigation);
    }

    // revert contract state to old state before litigation
    function setContractOutLitigation() public isMediator contractSigned isInLitigation isNotFinished {
        changeContractState(cOldState);
        cOldState = ContractState.None;
    }

    // add data proof to contract
    function addDataProof(string memory dId, string memory dHash) public dataProofDoesNotExists(dId) isOracle contractSigned isNotInLitigation isNotFinished {
        DataProof memory d = DataProof(dId, msg.sender, dHash, true);
        dataProofs[dId] = d;
        emit NewDataProof(dId, msg.sender);
    }

    // remove data from contract if needed (by mediator)
    function voidDataProof(string memory dId) public dataProofExists(dId) isMediator contractSigned isInLitigation isNotFinished {
        dataProofs[dId].dataValid = false;
        emit DataProofVoided(dId, msg.sender);
    }

    // Contract constructor
    constructor(address[] memory _participants, address[] memory _oracles, address[] memory _mediators) public {
        participants = _participants;
        oracles = _oracles;
        mediators = _mediators;
        changeContractState(ContractState.AwaitingSignature);
        cOldState = ContractState.None;
    }
}