// SERVICE LIBRARY FOR HANDLING SLC FUNCTIONS

const Engine = require('@accordproject/cicero-engine').Engine;
const engine = new Engine();
const Template = require('@accordproject/cicero-core').Template; 
const Clause = require('@accordproject/cicero-core').Clause;
const fs = require('fs');
let templateLocation = "./contracts/refrigerated-transportation/";

const clauseToReq = {
    "ShipmentAgreed": "shipmentagreedrequest.json",
    "AutomaticAgreement": "automaticagreementrequest.json",
    "BuyerPayment": "buyerpaymentrequest.json",
    "EndLitigation": "endlitigationrequest.json",
    "LateShipment": "lateshipmentrequest.json",
    "SetContractInLitigation": "setcontractinlitigationrequest.json",
    "ShipmentDelivered": "shipmentdeliveredrequest.json",
    "TemperatureExcess": "temperatureexcessrequest.json"
}

/**
 * makeResponse - build a response to return to the API
 * @param {Boolean} status true means that everything went well, false means that an error occurs or something is forbidden
 * @param {*} content the content to return
 * @param {String} code if an error occured, a code is return to indicate what went wrong
 */
function makeResponse(status, content, code) {
    if(status) {
        return {
            "success": status,
            "content": content
        }
    }
    else {
        return {
            "success": status,
            "errorCode": code,
            "error": content
        }
    }
}

/**
 * getClauseName - retrieve the namefile of a request and return it as an URI
 * @param {String} clauseName the clause to trigger
 */
function getClauseReq(clauseName) {
    const reqFile = clauseToReq[clauseName];
    if(!reqFile) {
        console.error("No request associated to this clause.");
        return false;
    }
    else return (templateLocation + "requests/" + reqFile);
}

/**
 * saveState - save the provided state in the smart legal contract
 * @param {JSON} jsonState the new contract state to save
 */
function saveState(jsonState) {
    try {
        fs.writeFileSync(templateLocation + 'state.json', JSON.stringify(jsonState));
        return true;
    }
    catch (e) {
        console.error("Writing state failed: " + e);
        return false;
    }
}

/**
 * loadJson - load a JSON text file from the server and parse it as JSON
 * @param {String} uri JSON file URI
 */
function loadJson(uri) {
    try {
        const rawData = fs.readFileSync(uri);
        if (!rawData) {
            console.error("Impossible to retrieve file " + uri + ": not found or forbidden.");
            return false;
        } 
        else {
            return JSON.parse(rawData);
        }
    }
    catch (e) {
        console.error("Impossible to retrieve file " + uri + ": " + e);
        return false;
    }
}

/**
 * makeRequest - make a request to a contract clause and store the state change if asked to
 * @param {String} clauseName the name of the triggered clause
 * @param {Boolean} doSaveState default to true, if disabled the state is not stored after the execution of the function
 */
async function makeRequest(clauseName, doSaveState = true) {
    try {
        const state = loadJson(templateLocation + 'state.json');
        const data = loadJson(templateLocation + 'data.json');
        const template = await Template.fromDirectory(templateLocation);
        const clause = new Clause(template);
        clause.setData(data);
        
        const request = require(getClauseReq(clauseName));
        if (request) {
            return engine.trigger(clause, request, state).then(res => {
                if(doSaveState) saveState(res.state);
                if(res) return makeResponse(true, res.response);
                else return makeResponse(false, res, "CLAUSE_EXECUTION_FAILED");
            })
            .catch(err => {
                return makeResponse(false, err, "CLAUSE_EXECUTION_DENIED");
            });
        }
        else return makeResponse(false, res, "REQUEST_NOT_FOUND");
    }
    catch (e) {
        console.error("Request to contract failed: " + e);
        return makeResponse(false, res, "CLAUSE_EXECUTION_FAILED");
    }
}

/**
 * initContract - initialize a smart legal contract using the static artifacts of it and store the generated state if asked to
 * @param {Boolean} doSaveState default to true, if disabled the state is not stored after the execution of the function
 */
async function initContract(doSaveState = true) {
    try {
        const data = loadJson(templateLocation + 'data.json');
        const template = await Template.fromDirectory(templateLocation);
        const clause = new Clause(template);
        clause.setData(data);
        
        return engine.init(clause).then(res => {
            if(doSaveState) {
                if(!saveState(res.state)) return makeResponse(false, "Impossible to save state.", "SAVE_STATE_ERROR");
            }
            if(res) return makeResponse(true, res.response);
            else return makeResponse(false, res, "CONTRACT_INITIALIZATION_FAILED");
        });
    }
    catch (e) {
        console.error("Contract initialization failed: " + e);
        return makeResponse(false, res, "CONTRACT_INITIALIZATION_FAILED");
    }
}

/**
 * testLib: called to check if everything works as planned
 */
async function testLib() {
    var initC = await initContract();
    var callOne = await makeRequest("ShipmentDelivered");
    var callTwo = await makeRequest("ShipmentDelivered");
    console.log(initC, callOne, callTwo)
}

//testLib()

module.exports = { makeRequest, initContract }