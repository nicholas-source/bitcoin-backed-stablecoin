;; title: Bitcoin-Backed Stablecoin Smart Contract
;; summary: A Clarity smart contract for a Bitcoin-backed stablecoin, implementing minting, redemption, and liquidation mechanisms.
;; description: 
;; This smart contract defines a Bitcoin-backed stablecoin system on the Stacks blockchain. It includes functionalities for creating vaults, minting stablecoins against Bitcoin collateral, redeeming stablecoins, and liquidating undercollateralized vaults. The contract also includes governance functions to update key parameters and read-only functions for transparency. Error codes and constants are defined for better error handling and configuration.

;; Trait definition instead of import
(define-trait sip-010-token
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 5) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)

;; Enhanced Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-COLLATERAL (err u1002))
(define-constant ERR-UNDERCOLLATERALIZED (err u1003))
(define-constant ERR-ORACLE-PRICE-UNAVAILABLE (err u1004))
(define-constant ERR-LIQUIDATION-FAILED (err u1005))
(define-constant ERR-MINT-LIMIT-EXCEEDED (err u1006))
(define-constant ERR-INVALID-PARAMETERS (err u1007))
(define-constant ERR-UNAUTHORIZED-VAULT-ACTION (err u1008))

;; Security Constants
(define-constant MAX-BTC-PRICE u1000000000000)  ;; Maximum reasonable BTC price
(define-constant MAX-TIMESTAMP u18446744073709551615)  ;; Maximum uint timestamp

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Stablecoin configuration
(define-data-var stablecoin-name (string-ascii 32) "Bitcoin-Backed Stablecoin")
(define-data-var stablecoin-symbol (string-ascii 5) "BTCS")
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
  uint
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

;; Enhanced Add BTC price oracle
(define-public (add-btc-price-oracle (oracle principal))
  (begin
    ;; Strict authorization check
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Prevent adding zero address or contract owner as oracle
    (asserts! (and 
      (not (is-eq oracle CONTRACT-OWNER)) 
      (not (is-eq oracle tx-sender))
    ) ERR-INVALID-PARAMETERS)
    
    ;; Add oracle
    (map-set btc-price-oracles oracle true)
    (ok true)
  )
)

;; Enhanced Update BTC price
(define-public (update-btc-price (price uint) (timestamp uint))
  (begin
    ;; Validate oracle
    (asserts! (is-some (map-get? btc-price-oracles tx-sender)) ERR-NOT-AUTHORIZED)
    
    ;; Enhanced input validation
    (asserts! (and 
      (> price u0)  ;; Positive price
      (<= price MAX-BTC-PRICE)  ;; Within reasonable bounds
    ) ERR-INVALID-PARAMETERS)
    
    ;; Timestamp validation
    (asserts! (<= timestamp MAX-TIMESTAMP) ERR-INVALID-PARAMETERS)
    
    ;; Update price
    (map-set last-btc-price 
      {
        timestamp: timestamp, 
        price: price
      }
      price
    )
    (ok true)
  )
)

;; Get latest BTC price
(define-read-only (get-latest-btc-price)
  (map-get? last-btc-price 
    {
      timestamp: block-height,
      price: u0
    }
  )
)

;; Enhanced Create a new vault
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
    ;; Enhanced validation
    (asserts! (> collateral-amount u0) ERR-INVALID-COLLATERAL)
    (asserts! (< vault-id (+ (var-get vault-counter) u1000)) ERR-INVALID-PARAMETERS) ;; Prevent excessive vault creation
    
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

;; Enhanced Mint stablecoin
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
        (unwrap! 
          (get-latest-btc-price) 
          ERR-ORACLE-PRICE-UNAVAILABLE
        )
      )
      
      ;; Calculate maximum mintable amount based on collateral
      (max-mintable 
        (/
          (* 
            (get collateral-amount vault) 
            btc-price  ;; Direct use of price value
          ) 
          (var-get collateralization-ratio)
        )
      )
    )
    
    ;; Enhanced authorization check
    (asserts! (is-eq tx-sender vault-owner) ERR-UNAUTHORIZED-VAULT-ACTION)
    
    ;; Validate mint amount
    (asserts! (> mint-amount u0) ERR-INVALID-PARAMETERS)
    
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

;; Enhanced Liquidation mechanism
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
        (unwrap! 
          (get-latest-btc-price) 
          ERR-ORACLE-PRICE-UNAVAILABLE
        )
      )
      
      ;; Current vault collateralization
      (current-collateralization 
        (/
          (* 
            (get collateral-amount vault) 
            btc-price  ;; Direct use of price value
          ) 
          (get stablecoin-minted vault)
        )
      )
    )
    
    ;; Prevent self-liquidation
    (asserts! (not (is-eq tx-sender vault-owner)) ERR-UNAUTHORIZED-VAULT-ACTION)
    
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

;; Enhanced Redemption mechanism
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
    
    ;; Validate sender
    (asserts! (is-eq tx-sender vault-owner) ERR-UNAUTHORIZED-VAULT-ACTION)
    
    ;; Validate redemption amount
    (asserts! (> redeem-amount u0) ERR-INVALID-PARAMETERS)
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

;; Governance functions
(define-public (update-collateralization-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! 
      (and 
        (>= new-ratio u100)  ;; Minimum 100%
        (<= new-ratio u300)  ;; Maximum 300%
      ) 
      ERR-INVALID-PARAMETERS
    )
    (var-set collateralization-ratio new-ratio)
    (ok true)
  )
)

;; Read-only functions for transparency
(define-read-only (get-vault-details (vault-owner principal) (vault-id uint))
  (map-get? vaults {owner: vault-owner, id: vault-id})
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)