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
        address pAddress;
        string signature;
    }

    struct Clause {
        //mapping participants to their signature
        string id;
        mapping(uint => Participant) participants;
        uint nbParticipants;
        string status;
    }

    struct DataProof {
        string id;
        address oAddress;
        string dataHash;
    }

    address[] public participants;
    address[] public oracles;
    address[] public mediators;
    mapping(string => Clause) public clauses;
    mapping(string => DataProof) public dataProofs;
    string public slcHash;

    ///// CONTRACT EVENTS /////

    // event to inform parties about a Clause update
    event ClauseUpdate(string id, string status);

    // event to inform parties about an added clause
    event ClauseAdded(string id, address pAddress);

    // event to inform parties about a deleted clause (by a mediator)
    event ClauseRemoved(string id, address mAddress);

    // event to inform parties about the cancellation of a clause (by a mediator)
    event ClauseCancelled(string id, address mAddress);

    // event to inform parties about new data proof on the contract
    event NewDataProof(string id, address oAddress);

    // event to inform parties about a deleted proof on the contract (by a mediator)
    event DataProofDeleted(string id, address mAddress);

    // event to inform parties about the contract signature
    event slcHashAdded(string slcHash, address pAddress);

    // event to inform parties about the removal of the signature by a mediator
    event slcHashRemoved(address mAddress);

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
        if(strHash(clauses[cId].status) == strHash("cancelled")) {
            revert("Clause is cancelled");
        }
        _;
    }

    // returns a hash of a string, used to compare them even between memory/storage values
    function strHash(string memory str) private pure returns(bytes32 ret) {
        return keccak256(abi.encodePacked(str));
    }

    ///// CONTRACT FUNCTIONS /////

    function addClause(string memory cId, address[] memory ps) public contractNotSigned clauseDoesNotExists(cId) isParticipant {
        Clause memory c = Clause(cId, ps.length, "awaiting");
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

    // remove a clause if needed (by mediator)
    function removeClause(string memory cId) public clauseExists(cId) isMediator contractNotSigned {
        delete clauses[cId];
        emit ClauseRemoved(cId, msg.sender);
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
    function addSlcHash(string memory _slcHash) public isParticipant contractNotSigned {
        slcHash = _slcHash;
        emit slcHashAdded(slcHash, msg.sender);
    }

    // remove the SLC hash to the contract if needed
    function removeSlcHash() public isMediator contractSigned {
        slcHash = "";
        emit slcHashRemoved(msg.sender);
    }

    // sign a clause
    function signClause(string memory cId, string memory signature) public clauseExists(cId) clauseNotCancelled(cId) isParticipant {
        for(uint i = 0; i < clauses[cId].nbParticipants; i++) {
            if(clauses[cId].participants[i].pAddress == msg.sender) {
                clauses[cId].participants[i].signature = signature;

                if(checkIfClauseIsSigned(cId)) {
                    clauses[cId].status = "accepted";
                    emit ClauseUpdate(cId, "accepted");
                }

                return;
            }
        }

        revert("Message sender is not a clause participant");
    }

    // remove a clause signature if needed, only executable by mediators
    function removeSignature(address pAddress, string memory cId) public clauseExists(cId) isMediator {
        for(uint i = 0; i < clauses[cId].nbParticipants; i++) {
            if(clauses[cId].participants[i].pAddress == pAddress) {
                clauses[cId].participants[i].signature = "";
                if(strHash(clauses[cId].status) == strHash("accepted")) {
                    clauses[cId].status = "awaiting";
                    emit ClauseUpdate(cId, "awaiting");
                }
                return;
            }
        }

        revert("Participant address provided is not in the clause");
    }

    // cancel a clause if needed (by mediator)
    function cancelClause(string memory cId) public clauseExists(cId) isMediator contractSigned {
        clauses[cId].status = "cancelled";
        emit ClauseCancelled(cId, msg.sender);
        emit ClauseUpdate(cId, "cancelled");
    }

    // add data proof to contract
    function addDataProof(string memory dId, string memory dHash) public dataProofDoesNotExists(dId) isOracle contractSigned {
        DataProof memory d = DataProof(dId, msg.sender, dHash);
        dataProofs[dId] = d;
        emit NewDataProof(dId, msg.sender);
    }

    // remove data from contract if needed (by mediator)
    function removeDataProof(string memory dId) public dataProofExists(dId) isMediator contractSigned {
        delete dataProofs[dId];
        emit DataProofDeleted(dId, msg.sender);
    }

    // Contract constructor
    constructor(address[] memory _participants, address[] memory _oracles, address[] memory _mediators) public {
        participants = _participants;
        oracles = _oracles;
        mediators = _mediators;
    }
}