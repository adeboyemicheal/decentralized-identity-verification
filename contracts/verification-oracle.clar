
;; title: verification-oracle
;; version: 1.0.0
;; summary: Decentralized verification oracle system
;; description: Manages verification requests, oracle responses, and identity scoring

;; traits
;;

;; token definitions
;;

;; constants
;;
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_REQUEST_EXPIRED (err u408))
(define-constant ERR_REQUEST_ALREADY_PROCESSED (err u409))
(define-constant ERR_INSUFFICIENT_STAKE (err u402))
(define-constant MIN_ORACLE_STAKE u1000)
(define-constant MAX_VERIFICATION_TIME u144) ;; 144 blocks ~ 24 hours
(define-constant MIN_ORACLE_SCORE u50)
(define-constant MAX_ORACLE_SCORE u100)
(define-constant ORACLE_REWARD u10)
(define-constant REQUEST_FEE u5)

;; data vars
;;
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var next-request-id uint u1)
(define-data-var total-oracles uint u0)
(define-data-var total-requests uint u0)
(define-data-var oracle-registry-enabled bool true)
(define-data-var min-consensus-threshold uint u3)

;; data maps
;;
(define-map verification-requests
  uint
  {
    requester: principal,
    target-identity: principal,
    request-type: (string-ascii 50),
    timestamp: uint,
    expiration: uint,
    status: (string-ascii 20),
    consensus-score: uint,
    total-responses: uint,
    stake-amount: uint
  }
)

(define-map oracle-registry
  principal
  {
    registered: bool,
    stake-amount: uint,
    reputation-score: uint,
    total-responses: uint,
    successful-responses: uint,
    registration-timestamp: uint,
    last-activity: uint
  }
)

(define-map oracle-responses
  { request-id: uint, oracle: principal }
  {
    response: bool,
    confidence-score: uint,
    evidence-hash: (buff 32),
    timestamp: uint,
    processed: bool
  }
)

(define-map identity-scores
  principal
  {
    overall-score: uint,
    verification-count: uint,
    last-updated: uint,
    score-history: (list 10 uint)
  }
)

(define-map request-consensus
  uint
  {
    positive-votes: uint,
    negative-votes: uint,
    total-votes: uint,
    consensus-reached: bool,
    final-result: (optional bool)
  }
)

(define-map oracle-stakes principal uint)

;; public functions
;;

;; Register as an oracle (requires stake)
(define-public (register-oracle (stake-amount uint))
  (begin
    (asserts! (var-get oracle-registry-enabled) (err u503))
    (asserts! (>= stake-amount MIN_ORACLE_STAKE) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-none (map-get? oracle-registry tx-sender)) ERR_ALREADY_EXISTS)
    
    ;; In a real implementation, this would transfer STX tokens as stake
    (map-set oracle-stakes tx-sender stake-amount)
    
    (map-set oracle-registry tx-sender {
      registered: true,
      stake-amount: stake-amount,
      reputation-score: u75, ;; Starting reputation
      total-responses: u0,
      successful-responses: u0,
      registration-timestamp: block-height,
      last-activity: block-height
    })
    
    (var-set total-oracles (+ (var-get total-oracles) u1))
    
    (print {
      event: "oracle-registered",
      oracle: tx-sender,
      stake: stake-amount,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Submit verification request
(define-public (request-verification (target-identity principal) (request-type (string-ascii 50)) (stake-amount uint))
  (let (
    (request-id (var-get next-request-id))
    (expiration-block (+ block-height MAX_VERIFICATION_TIME))
  )
    (asserts! (>= stake-amount REQUEST_FEE) ERR_INSUFFICIENT_STAKE)
    (asserts! (> (len request-type) u0) ERR_INVALID_INPUT)
    
    (map-set verification-requests request-id {
      requester: tx-sender,
      target-identity: target-identity,
      request-type: request-type,
      timestamp: block-height,
      expiration: expiration-block,
      status: "pending",
      consensus-score: u0,
      total-responses: u0,
      stake-amount: stake-amount
    })
    
    (map-set request-consensus request-id {
      positive-votes: u0,
      negative-votes: u0,
      total-votes: u0,
      consensus-reached: false,
      final-result: none
    })
    
    (var-set next-request-id (+ request-id u1))
    (var-set total-requests (+ (var-get total-requests) u1))
    
    (print {
      event: "verification-requested",
      request-id: request-id,
      requester: tx-sender,
      target: target-identity,
      type: request-type,
      timestamp: block-height
    })
    
    (ok request-id)
  )
)

;; Oracle responds to verification request
(define-public (oracle-respond (request-id uint) (response bool) (confidence-score uint) (evidence-hash (buff 32)))
  (let (
    (request-data (unwrap! (map-get? verification-requests request-id) ERR_NOT_FOUND))
    (oracle-data (unwrap! (map-get? oracle-registry tx-sender) ERR_UNAUTHORIZED))
    (consensus-data (unwrap! (map-get? request-consensus request-id) ERR_NOT_FOUND))
  )
    (asserts! (get registered oracle-data) ERR_UNAUTHORIZED)
    (asserts! (<= block-height (get expiration request-data)) ERR_REQUEST_EXPIRED)
    (asserts! (is-eq (get status request-data) "pending") ERR_REQUEST_ALREADY_PROCESSED)
    (asserts! (is-none (map-get? oracle-responses { request-id: request-id, oracle: tx-sender })) ERR_ALREADY_EXISTS)
    (asserts! (and (>= confidence-score u1) (<= confidence-score u100)) ERR_INVALID_INPUT)
    
    ;; Record oracle response
    (map-set oracle-responses { request-id: request-id, oracle: tx-sender } {
      response: response,
      confidence-score: confidence-score,
      evidence-hash: evidence-hash,
      timestamp: block-height,
      processed: false
    })
    
    ;; Update consensus tracking
    (let (
      (new-positive (if response (+ (get positive-votes consensus-data) u1) (get positive-votes consensus-data)))
      (new-negative (if response (get negative-votes consensus-data) (+ (get negative-votes consensus-data) u1)))
      (new-total (+ (get total-votes consensus-data) u1))
    )
      (map-set request-consensus request-id {
        positive-votes: new-positive,
        negative-votes: new-negative,
        total-votes: new-total,
        consensus-reached: (>= new-total (var-get min-consensus-threshold)),
        final-result: (if (>= new-total (var-get min-consensus-threshold))
                        (some (> new-positive new-negative))
                        none)
      })
      
      ;; Update request status if consensus reached
      (if (>= new-total (var-get min-consensus-threshold))
        (map-set verification-requests request-id (merge request-data {
          status: "completed",
          consensus-score: (/ (* new-positive u100) new-total),
          total-responses: new-total
        }))
        (map-set verification-requests request-id (merge request-data {
          total-responses: new-total
        }))
      )
    )
    
    ;; Update oracle activity
    (map-set oracle-registry tx-sender (merge oracle-data {
      total-responses: (+ (get total-responses oracle-data) u1),
      last-activity: block-height
    }))
    
    (print {
      event: "oracle-response",
      oracle: tx-sender,
      request-id: request-id,
      response: response,
      confidence: confidence-score,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Score identity based on verification results
(define-public (score-identity (target-identity principal) (new-score uint))
  (let (
    (current-score (default-to { overall-score: u50, verification-count: u0, last-updated: u0, score-history: (list) } 
                                (map-get? identity-scores target-identity)))
  )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (match (map-get? oracle-registry tx-sender) 
                    oracle-data (get registered oracle-data) 
                    false)) ERR_UNAUTHORIZED)
    (asserts! (and (>= new-score u0) (<= new-score u100)) ERR_INVALID_INPUT)
    
    (let (
      (updated-score (/ (+ (get overall-score current-score) new-score) u2))
      (new-history (unwrap-panic (as-max-len? (append (get score-history current-score) new-score) u10)))
    )
      (map-set identity-scores target-identity {
        overall-score: updated-score,
        verification-count: (+ (get verification-count current-score) u1),
        last-updated: block-height,
        score-history: new-history
      })
      
      (print {
        event: "identity-scored",
        identity: target-identity,
        scorer: tx-sender,
        new-score: updated-score,
        timestamp: block-height
      })
      
      (ok updated-score)
    )
  )
)

;; Set oracle (admin function)
(define-public (set-oracle-status (oracle principal) (active bool))
  (let (
    (oracle-data (unwrap! (map-get? oracle-registry oracle) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (map-set oracle-registry oracle (merge oracle-data {
      registered: active
    }))
    
    (print {
      event: "oracle-status-changed",
      oracle: oracle,
      active: active,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Update oracle reputation (based on performance)
(define-public (update-oracle-reputation (oracle principal) (performance-score uint))
  (let (
    (oracle-data (unwrap! (map-get? oracle-registry oracle) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (and (>= performance-score MIN_ORACLE_SCORE) (<= performance-score MAX_ORACLE_SCORE)) ERR_INVALID_INPUT)
    
    (let (
      (new-reputation (/ (+ (get reputation-score oracle-data) performance-score) u2))
    )
      (map-set oracle-registry oracle (merge oracle-data {
        reputation-score: new-reputation,
        successful-responses: (if (>= performance-score u75) 
                                (+ (get successful-responses oracle-data) u1)
                                (get successful-responses oracle-data))
      }))
      
      (print {
        event: "oracle-reputation-updated",
        oracle: oracle,
        new-reputation: new-reputation,
        timestamp: block-height
      })
      
      (ok new-reputation)
    )
  )
)

;; Withdraw oracle stake (if leaving)
(define-public (withdraw-oracle-stake)
  (let (
    (oracle-data (unwrap! (map-get? oracle-registry tx-sender) ERR_NOT_FOUND))
    (stake-amount (unwrap! (map-get? oracle-stakes tx-sender) ERR_NOT_FOUND))
  )
    (asserts! (get registered oracle-data) ERR_UNAUTHORIZED)
    
    ;; Mark oracle as unregistered
    (map-set oracle-registry tx-sender (merge oracle-data {
      registered: false
    }))
    
    ;; Remove stake record (in real implementation, transfer STX back)
    (map-delete oracle-stakes tx-sender)
    
    (var-set total-oracles (- (var-get total-oracles) u1))
    
    (print {
      event: "oracle-stake-withdrawn",
      oracle: tx-sender,
      amount: stake-amount,
      timestamp: block-height
    })
    
    (ok stake-amount)
  )
)

;; read only functions
;;

;; Get verification request details
(define-read-only (get-verification-request (request-id uint))
  (map-get? verification-requests request-id)
)

;; Get request status and consensus
(define-read-only (get-request-status (request-id uint))
  (match (map-get? verification-requests request-id)
    request (some {
      status: (get status request),
      consensus-score: (get consensus-score request),
      total-responses: (get total-responses request),
      expired: (> block-height (get expiration request))
    })
    none
  )
)

;; Get identity score
(define-read-only (get-score (identity principal))
  (match (map-get? identity-scores identity)
    score-data (some (get overall-score score-data))
    none
  )
)

;; Get identity verification history
(define-read-only (get-identity-verification-history (identity principal))
  (map-get? identity-scores identity)
)

;; Get oracle information
(define-read-only (get-oracle-info (oracle principal))
  (map-get? oracle-registry oracle)
)

;; Check if oracle is registered and active
(define-read-only (is-oracle-active (oracle principal))
  (match (map-get? oracle-registry oracle)
    oracle-data (get registered oracle-data)
    false
  )
)

;; Get oracle response to specific request
(define-read-only (get-oracle-response (request-id uint) (oracle principal))
  (map-get? oracle-responses { request-id: request-id, oracle: oracle })
)

;; Get consensus data for request
(define-read-only (get-consensus-data (request-id uint))
  (map-get? request-consensus request-id)
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-oracles: (var-get total-oracles),
    total-requests: (var-get total-requests),
    next-request-id: (var-get next-request-id),
    contract-owner: (var-get contract-owner),
    registry-enabled: (var-get oracle-registry-enabled),
    consensus-threshold: (var-get min-consensus-threshold)
  }
)

;; private functions
;;

;; Calculate consensus result
(define-private (calculate-consensus (positive uint) (negative uint) (total uint))
  (if (> total u0)
    (> (* positive u100) (* negative u100))
    false
  )
)

;; Validate oracle eligibility
(define-private (is-oracle-eligible (oracle principal))
  (match (map-get? oracle-registry oracle)
    oracle-data (and 
      (get registered oracle-data)
      (>= (get reputation-score oracle-data) MIN_ORACLE_SCORE)
      (>= (get stake-amount oracle-data) MIN_ORACLE_STAKE)
    )
    false
  )
)

