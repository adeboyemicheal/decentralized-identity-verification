
;; title: identity-registry
;; version: 1.0.0
;; summary: Decentralized identity verification registry
;; description: Manages user identity registration, verification, and access control

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
(define-constant ERR_IDENTITY_REVOKED (err u403))
(define-constant ERR_IDENTITY_NOT_VERIFIED (err u402))
(define-constant MAX_IDENTITY_LENGTH u1024)
(define-constant MIN_IDENTITY_LENGTH u10)
(define-constant VERIFICATION_THRESHOLD u75)

;; data vars
;;
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var total-identities uint u0)
(define-data-var verification-authority principal CONTRACT_OWNER)
(define-data-var contract-paused bool false)

;; data maps
;;
(define-map identities 
  principal 
  {
    info: (buff 1024),
    verified: bool,
    timestamp: uint,
    score: uint,
    revoked: bool,
    verification-count: uint
  }
)

(define-map identity-verification-history
  { identity: principal, request-id: uint }
  {
    verifier: principal,
    timestamp: uint,
    result: bool,
    notes: (buff 256)
  }
)

(define-map verification-requests
  uint
  {
    requester: principal,
    target-identity: principal,
    timestamp: uint,
    status: (string-ascii 20),
    result: (optional bool)
  }
)

(define-map authorized-verifiers principal bool)

;; public functions
;;

;; Register a new identity
(define-public (register-identity (identity-info (buff 1024)))
  (begin
    (asserts! (not (var-get contract-paused)) (err u503))
    (asserts! (is-none (map-get? identities tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (>= (len identity-info) MIN_IDENTITY_LENGTH) ERR_INVALID_INPUT)
    (asserts! (<= (len identity-info) MAX_IDENTITY_LENGTH) ERR_INVALID_INPUT)
    
    (map-set identities tx-sender {
      info: identity-info,
      verified: false,
      timestamp: block-height,
      score: u0,
      revoked: false,
      verification-count: u0
    })
    
    (var-set total-identities (+ (var-get total-identities) u1))
    
    (print {
      event: "identity-registered",
      identity: tx-sender,
      timestamp: block-height
    })
    
    (ok tx-sender)
  )
)

;; Update existing identity information
(define-public (update-identity (new-info (buff 1024)))
  (let (
    (existing-identity (unwrap! (map-get? identities tx-sender) ERR_NOT_FOUND))
  )
    (asserts! (not (var-get contract-paused)) (err u503))
    (asserts! (not (get revoked existing-identity)) ERR_IDENTITY_REVOKED)
    (asserts! (>= (len new-info) MIN_IDENTITY_LENGTH) ERR_INVALID_INPUT)
    (asserts! (<= (len new-info) MAX_IDENTITY_LENGTH) ERR_INVALID_INPUT)
    
    (map-set identities tx-sender (merge existing-identity {
      info: new-info,
      timestamp: block-height
    }))
    
    (print {
      event: "identity-updated",
      identity: tx-sender,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Verify an identity (only by authorized verifiers)
(define-public (verify-identity (target-identity principal) (verification-score uint) (notes (buff 256)))
  (let (
    (existing-identity (unwrap! (map-get? identities target-identity) ERR_NOT_FOUND))
    (request-id (var-get total-identities))
  )
    (asserts! (not (var-get contract-paused)) (err u503))
    (asserts! (or (is-eq tx-sender (var-get verification-authority)) 
                  (default-to false (map-get? authorized-verifiers tx-sender))) ERR_UNAUTHORIZED)
    (asserts! (not (get revoked existing-identity)) ERR_IDENTITY_REVOKED)
    (asserts! (<= verification-score u100) ERR_INVALID_INPUT)
    
    (let (
      (new-score (/ (+ (get score existing-identity) verification-score) u2))
      (is-verified (>= new-score VERIFICATION_THRESHOLD))
    )
      (map-set identities target-identity (merge existing-identity {
        verified: is-verified,
        score: new-score,
        verification-count: (+ (get verification-count existing-identity) u1)
      }))
      
      (map-set identity-verification-history 
        { identity: target-identity, request-id: request-id }
        {
          verifier: tx-sender,
          timestamp: block-height,
          result: is-verified,
          notes: notes
        }
      )
      
      (print {
        event: "identity-verified",
        identity: target-identity,
        verifier: tx-sender,
        score: new-score,
        verified: is-verified,
        timestamp: block-height
      })
      
      (ok is-verified)
    )
  )
)

;; Revoke an identity (only by contract owner or verification authority)
(define-public (revoke-identity (target-identity principal) (reason (buff 256)))
  (let (
    (existing-identity (unwrap! (map-get? identities target-identity) ERR_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-eq tx-sender (var-get verification-authority))) ERR_UNAUTHORIZED)
    (asserts! (not (get revoked existing-identity)) ERR_ALREADY_EXISTS)
    
    (map-set identities target-identity (merge existing-identity {
      revoked: true,
      verified: false,
      score: u0
    }))
    
    (print {
      event: "identity-revoked",
      identity: target-identity,
      revoker: tx-sender,
      reason: reason,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier true)
    
    (print {
      event: "verifier-added",
      verifier: verifier,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Remove authorized verifier (only contract owner)
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete authorized-verifiers verifier)
    
    (print {
      event: "verifier-removed",
      verifier: verifier,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Update contract owner (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    
    (print {
      event: "ownership-transferred",
      old-owner: tx-sender,
      new-owner: new-owner,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Pause/unpause contract (only contract owner)
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-paused paused)
    
    (print {
      event: "contract-pause-changed",
      paused: paused,
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; read only functions
;;

;; Get identity information
(define-read-only (get-identity (identity principal))
  (map-get? identities identity)
)

;; Check if identity is verified
(define-read-only (is-verified (identity principal))
  (match (map-get? identities identity)
    identity-data (and (get verified identity-data) (not (get revoked identity-data)))
    false
  )
)

;; Get identity score
(define-read-only (get-identity-score (identity principal))
  (match (map-get? identities identity)
    identity-data (some (get score identity-data))
    none
  )
)

;; Check if identity is revoked
(define-read-only (is-identity-revoked (identity principal))
  (match (map-get? identities identity)
    identity-data (get revoked identity-data)
    false
  )
)

;; Get verification history
(define-read-only (get-verification-history (identity principal) (request-id uint))
  (map-get? identity-verification-history { identity: identity, request-id: request-id })
)

;; Check if verifier is authorized
(define-read-only (is-authorized-verifier (verifier principal))
  (or (is-eq verifier (var-get verification-authority))
      (default-to false (map-get? authorized-verifiers verifier)))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-identities: (var-get total-identities),
    contract-owner: (var-get contract-owner),
    verification-authority: (var-get verification-authority),
    contract-paused: (var-get contract-paused)
  }
)

;; private functions
;;

;; Validate identity data format
(define-private (validate-identity-format (identity-info (buff 1024)))
  (and 
    (>= (len identity-info) MIN_IDENTITY_LENGTH)
    (<= (len identity-info) MAX_IDENTITY_LENGTH)
  )
)

