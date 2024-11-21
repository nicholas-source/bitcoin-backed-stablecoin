;; title: Bitcoin-Backed Stablecoin Smart Contract
;; summary: A Clarity smart contract for a Bitcoin-backed stablecoin, implementing minting, redemption, and liquidation mechanisms.
;; description: 
;; This smart contract defines a Bitcoin-backed stablecoin system on the Stacks blockchain. It includes functionalities for creating vaults, minting stablecoins against Bitcoin collateral, redeeming stablecoins, and liquidating undercollateralized vaults. The contract also includes governance functions to update key parameters and read-only functions for transparency. Error codes and constants are defined for better error handling and configuration.

;; Imports and constants
(use-trait sip-010-token 'ST1HTBVD3FMGZH8N4ZTH5AQ7MWDXJ3MV7QRYQ8A4.sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-COLLATERAL (err u1002))
(define-constant ERR-UNDERCOLLATERALIZED (err u1003))
(define-constant ERR-ORACLE-PRICE-UNAVAILABLE (err u1004))
(define-constant ERR-LIQUIDATION-FAILED (err u1005))
(define-constant ERR-MINT-LIMIT-EXCEEDED (err u1006))
(define-constant ERR-INVALID-PARAMETERS (err u1007))