// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    ////////////////////////////
    ////////Errors//////////////
    ////////////////////////////
    error MinimalAccount__NotFromEntryPoint();

    ////////////////////////////
    ////////State variable//////
    ////////////////////////////
    IEntryPoint private immutable i_entryPoint;

    ////////////////////////////
    ////////Modifiers///////////
    ////////////////////////////
    modifier fromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    ////////////////////////////
    ////////Functions///////////
    ////////////////////////////
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    ////////////////////////////
    ////External Functions//////
    ////////////////////////////

    /**
     *
     * @param userOp The user operation struct which contains details of the transaction
     * @param userOpHash The hash of the struct which contains signature of msg.sender
     * @param missingAccountFunds the money to pay the entry point contract
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        fromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        //_validateNonce() - this could have been done but it's handled by the entrypoint contract
        _payPrefund(missingAccountFunds); //to pay the entrypoint contract
    }

    ////////////////////////////
    /////Internal Functions/////
    ////////////////////////////
    /**
     *
     * @param userOp The packed user operation which contains the AA transaction details
     * @param userOpHash The hashed version of the userOp which contains signature of the sender
     * @notice userOpHash fed to this function is the EIP 191 version of the signed hash, this needs to be converted to a normal hash
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice This function is for paying the EntryPoint contract money from our smart account
     * @param missingAccountFunds to pay the EntryPoint contract for the transaction
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    /////////////////////////////////
    ////////View and Pure Functions//
    /////////////////////////////////
    /**
     * @notice returns address of the entry point contract
     */
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
