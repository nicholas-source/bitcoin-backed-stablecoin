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

;; Vault structure
(define-map vaults 
  {
    owner: principal, 
    id: uint
  }
  {
    collateral-amount: uint,  ;; BTC amount as collateral
    stablecoin-minted: uint,  ;; Minted stablecoin amount
    created-at: uint          ;; Timestamp of vault creation
  }
)

;; Vault counter
(define-data-var vault-counter uint u0)

;; Add BTC price oracle
(define-public (add-btc-price-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set btc-price-oracles oracle true)
    (ok true)
  )
)

;; Update BTC price
(define-public (update-btc-price (price uint) (timestamp uint))
  (begin
    (asserts! (is-some (map-get? btc-price-oracles tx-sender)) ERR-NOT-AUTHORIZED)
    (map-set last-btc-price 
      {
        timestamp: timestamp, 
        price: price
      }
    )
    (ok true)
  )
)

;; Get latest BTC price
(define-read-only (get-latest-btc-price)
  (map-get? last-btc-price 
    {
      timestamp: (var-get block-height), 
      price: (default-to u0 (get price (map-get? last-btc-price {timestamp: (var-get block-height), price: u0})))
    }
  )
)

;; Create a new vault
(define-public (create-vault (collateral-amount uint))
  (let 
    (
      (vault-id (+ (var-get vault-counter) u1))
      (new-vault 
        {
          owner: tx-sender,
          id: vault-id
        }
      )
    )
    (asserts! (> collateral-amount u0) ERR-INVALID-COLLATERAL)
    
    ;; Increment vault counter
    (var-set vault-counter vault-id)
    
    ;; Store vault details
    (map-set vaults new-vault 
      {
        collateral-amount: collateral-amount,
        stablecoin-minted: u0,
        created-at: block-height
      }
    )
    
    (ok vault-id)
  )
)

;; Mint stablecoin
(define-public (mint-stablecoin 
  (vault-owner principal)
  (vault-id uint)
  (mint-amount uint)
)
  (let
    (
      ;; Retrieve vault details
      (vault 
        (unwrap! 
          (map-get? vaults {owner: vault-owner, id: vault-id}) 
          ERR-INVALID-PARAMETERS
        )
      )
      
      ;; Get latest BTC price
      (btc-price 
        (unwrap! (get-latest-btc-price) ERR-ORACLE-PRICE-UNAVAILABLE)
      )
      
      ;; Calculate maximum mintable amount based on collateral
      (max-mintable 
        (/
          (* 
            (get collateral-amount vault) 
            btc-price 
          ) 
          (var-get collateralization-ratio)
        )
      )
    )
    
    ;; Validate minting conditions
    (asserts! 
      (>= 
        max-mintable 
        (+ (get stablecoin-minted vault) mint-amount)
      ) 
      ERR-UNDERCOLLATERALIZED
    )
    
    ;; Check mint limit
    (asserts! 
      (<= 
        (+ (get stablecoin-minted vault) mint-amount) 
        (var-get max-mint-limit)
      ) 
      ERR-MINT-LIMIT-EXCEEDED
    )
    
    ;; Update vault with minted amount
    (map-set vaults {owner: vault-owner, id: vault-id}
      {
        collateral-amount: (get collateral-amount vault),
        stablecoin-minted: (+ (get stablecoin-minted vault) mint-amount),
        created-at: (get created-at vault)
      }
    )
    
    ;; Update total supply
    (var-set total-supply 
      (+ (var-get total-supply) mint-amount)
    )
    
    (ok true)
  )
)

;; Liquidation mechanism
(define-public (liquidate-vault 
  (vault-owner principal)
  (vault-id uint)
)
  (let
    (
      ;; Retrieve vault details
      (vault 
        (unwrap! 
          (map-get? vaults {owner: vault-owner, id: vault-id}) 
          ERR-INVALID-PARAMETERS
        )
      )
      
      ;; Get latest BTC price
      (btc-price 
        (unwrap! (get-latest-btc-price) ERR-ORACLE-PRICE-UNAVAILABLE)
      )
      
      ;; Current vault collateralization
      (current-collateralization 
        (/
          (* 
            (get collateral-amount vault) 
            btc-price 
          ) 
          (get stablecoin-minted vault)
        )
      )
    )
    
    ;; Check if vault is liquidatable
    (asserts! 
      (< current-collateralization (var-get liquidation-threshold)) 
      ERR-LIQUIDATION-FAILED
    )
    
    ;; Perform liquidation
    ;; 1. Seize collateral
    ;; 2. Burn minted stablecoins
    
    ;; Update total supply
    (var-set total-supply 
      (- (var-get total-supply) (get stablecoin-minted vault))
    )
    
    ;; Remove vault
    (map-delete vaults {owner: vault-owner, id: vault-id})
    
    (ok true)
  )
)

;; Redemption mechanism
(define-public (redeem-stablecoin 
  (vault-owner principal)
  (vault-id uint)
  (redeem-amount uint)
)
  (let
    (
      ;; Retrieve vault details
      (vault 
        (unwrap! 
          (map-get? vaults {owner: vault-owner, id: vault-id}) 
          ERR-INVALID-PARAMETERS
        )
      )
    )
    
    ;; Validate redemption amount
    (asserts! 
      (<= redeem-amount (get stablecoin-minted vault)) 
      ERR-INSUFFICIENT-BALANCE
    )
    
    ;; Update vault with redeemed amount
    (map-set vaults {owner: vault-owner, id: vault-id}
      {
        collateral-amount: (get collateral-amount vault),
        stablecoin-minted: (- (get stablecoin-minted vault) redeem-amount),
        created-at: (get created-at vault)
      }
    )
    
    ;; Update total supply
    (var-set total-supply 
      (- (var-get total-supply) redeem-amount)
    )
    
    (ok true)
  )
)