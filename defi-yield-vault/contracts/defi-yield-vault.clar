;; Yield Vault Contract
;; Allows users to deposit STX and earn yield

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_VAULT_PAUSED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_WITHDRAWAL_FAILED (err u104))

;; Data Variables
(define-data-var vault-paused bool false)
(define-data-var total-deposits uint u0)
(define-data-var yield-rate uint u500) ;; 5% annual yield (500 basis points)

;; Data Maps
(define-map user-deposits principal uint)
(define-map user-last-claim principal uint)

;; Helper function to get minimum of two values
(define-private (min-value (a uint) (b uint))
  (if (<= a b) a b)
)

;; Read-only functions
(define-read-only (get-user-deposit (user principal))
  (default-to u0 (map-get? user-deposits user))
)

(define-read-only (get-total-deposits)
  (var-get total-deposits)
)

(define-read-only (get-yield-rate)
  (var-get yield-rate)
)

(define-read-only (is-vault-paused)
  (var-get vault-paused)
)

(define-read-only (calculate-yield (user principal))
  (let (
    (deposit (get-user-deposit user))
    (last-claim (default-to stacks-block-height (map-get? user-last-claim user)))
    (blocks-elapsed (- stacks-block-height last-claim))
  )
    (if (> deposit u0)
      (/ (* deposit (var-get yield-rate) blocks-elapsed) u1000000)
      u0
    )
  )
)

;; Public functions
(define-public (deposit-stx (amount uint))
  (begin
    (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (let (
      (current-deposit (get-user-deposit tx-sender))
      (new-deposit (+ current-deposit amount))
    )
      (map-set user-deposits tx-sender new-deposit)
      (map-set user-last-claim tx-sender stacks-block-height)
      (var-set total-deposits (+ (var-get total-deposits) amount))
      (ok new-deposit)
    )
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-deposit (get-user-deposit tx-sender))
      (yield-earned (calculate-yield tx-sender))
      (total-available (+ current-deposit yield-earned))
    )
      (asserts! (>= total-available amount) ERR_INSUFFICIENT_BALANCE)
      
      (let (
        (withdraw-from-deposit (min-value amount current-deposit))
        (new-deposit (- current-deposit withdraw-from-deposit))
      )
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-deposits tx-sender new-deposit)
        (map-set user-last-claim tx-sender stacks-block-height)
        (var-set total-deposits (- (var-get total-deposits) withdraw-from-deposit))
        (ok amount)
      )
    )
  )
)

(define-public (claim-yield)
  (let (
    (yield-earned (calculate-yield tx-sender))
  )
    (asserts! (> yield-earned u0) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)
    
    (try! (as-contract (stx-transfer? yield-earned tx-sender tx-sender)))
    (map-set user-last-claim tx-sender stacks-block-height)
    (ok yield-earned)
  )
)

;; Admin functions
(define-public (set-yield-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set yield-rate new-rate)
    (ok true)
  )
)

(define-public (pause-vault)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set vault-paused true)
    (ok true)
  )
)

(define-public (unpause-vault)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set vault-paused false)
    (ok true)
  )
)

;; Emergency withdrawal function for contract owner
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok amount)
  )
)

;; Get user's total balance (deposit + yield)
(define-public (get-user-balance (user principal))
  (let (
    (current-deposit (get-user-deposit user))
    (yield-earned (calculate-yield user))
  )
    (ok (+ current-deposit yield-earned))
  )
)

;; Compound yield - add earned yield to principal
(define-public (compound-yield)
  (let (
    (yield-earned (calculate-yield tx-sender))
    (current-deposit (get-user-deposit tx-sender))
  )
    (asserts! (> yield-earned u0) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)
    
    (let (
      (new-deposit (+ current-deposit yield-earned))
    )
      (map-set user-deposits tx-sender new-deposit)
      (map-set user-last-claim tx-sender stacks-block-height)
      (var-set total-deposits (+ (var-get total-deposits) yield-earned))
      (ok new-deposit)
    )
  )
)

;; Partial withdrawal - withdraw specific amount from deposit only
(define-public (partial-withdraw (amount uint))
  (begin
    (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-deposit (get-user-deposit tx-sender))
    )
      (asserts! (>= current-deposit amount) ERR_INSUFFICIENT_BALANCE)
      
      (let (
        (new-deposit (- current-deposit amount))
      )
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-deposits tx-sender new-deposit)
        (var-set total-deposits (- (var-get total-deposits) amount))
        (ok amount)
      )
    )
  )
)

;; Get vault statistics
(define-public (get-vault-stats)
  (let (
    (total-stx (get-total-deposits))
    (current-yield-rate (get-yield-rate))
    (vault-status (is-vault-paused))
  )
    (ok {
      total-deposits: total-stx,
      yield-rate: current-yield-rate,
      is-paused: vault-status,
      contract-balance: (stx-get-balance (as-contract tx-sender))
    })
  )
)
