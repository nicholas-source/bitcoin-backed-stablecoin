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

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Stablecoin configuration
(define-data-var stablecoin-name (string-ascii 32) "Bitcoin-Backed Stablecoin")
(define-data-var stablecoin-symbol (string-ascii 5) "BTCUSD")
(define-data-var total-supply uint u0)
(define-data-var collateralization-ratio uint u150) ;; 150% minimum collateral
(define-data-var liquidation-threshold uint u125) ;; 125% liquidation starts

;; Governance parameters
(define-data-var mint-fee-bps uint u50) ;; 0.5% minting fee
(define-data-var redemption-fee-bps uint u50) ;; 0.5% redemption fee
(define-data-var max-mint-limit uint u1000000) ;; Prevent excessive minting

;; Oracles and price feeds
(define-map btc-price-oracles principal bool)

(define-map last-btc-price 
  {
    timestamp: uint,
    price: uint
  }
)