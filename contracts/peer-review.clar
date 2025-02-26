;; Consensus Protocol
;; Description: A smart contract that facilitates expert evaluation of academic manuscripts and compensates evaluators

;; Constants for error handling
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MANUSCRIPT-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EVALUATED (err u102))
(define-constant ERR-INVALID-RATING (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-NOT-EVALUATOR (err u105))
(define-constant ERR-MANUSCRIPT-EXISTS (err u106))
(define-constant ERR-EMPTY-HASH (err u107))
(define-constant ERR-INVALID-ID (err u108))
(define-constant ERR-EMPTY-REASON (err u109))
(define-constant ERR-SELF-DISPUTE (err u110))
(define-constant ERR-EMPTY-STATUS (err u111))
(define-constant ERR-INVALID-STATUS (err u112))
(define-constant ERR-ALREADY-REGISTERED (err u113))

;; Data Variables
(define-data-var min-collateral uint u100)
(define-data-var evaluation-honorarium uint u50)
(define-data-var protocol-admin principal tx-sender)

;; Data Maps
(define-map Manuscripts 
    { manuscript-id: uint }
    {
        scholar: principal,
        ipfs-hash: (string-ascii 64),
        status: (string-ascii 20),
        evaluation-count: uint,
        total-rating: uint,
        timestamp: uint
    }
)

(define-map Evaluations
    { manuscript-id: uint, evaluator: principal }
    {
        rating: uint,
        comment-hash: (string-ascii 64),
        timestamp: uint,
        status: (string-ascii 20)
    }
)

(define-map Evaluators
    { evaluator: principal }
    {
        collateral: uint,
        evaluation-count: uint,
        credibility: uint,
        status: (string-ascii 20)
    }
)

;; Authorization check
(define-private (is-protocol-admin)
    (is-eq tx-sender (var-get protocol-admin))
)

;; Submit new manuscript
(define-public (submit-manuscript (ipfs-hash (string-ascii 64)) (manuscript-id uint))
    (let
        (
            (manuscript-data {
                scholar: tx-sender,
                ipfs-hash: ipfs-hash,
                status: "pending",
                evaluation-count: u0,
                total-rating: u0,
                timestamp: block-height
            })
        )
        (asserts! (> (len ipfs-hash) u0) ERR-EMPTY-HASH)
        (asserts! (>= manuscript-id u0) ERR-INVALID-ID)
        (asserts! (is-none (map-get? Manuscripts { manuscript-id: manuscript-id })) ERR-MANUSCRIPT-EXISTS)
        
        (ok (map-set Manuscripts { manuscript-id: manuscript-id } manuscript-data))
    )
)

;; Register as evaluator
(define-public (register-evaluator)
    (let
        (
            (collateral-amount (var-get min-collateral))
            (evaluator-data {
                collateral: collateral-amount,
                evaluation-count: u0,
                credibility: u100,
                status: "active"
            })
        )
        (asserts! (is-none (map-get? Evaluators { evaluator: tx-sender })) ERR-ALREADY-REGISTERED)
        (asserts! (>= (stx-get-balance tx-sender) collateral-amount) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        (ok (map-set Evaluators { evaluator: tx-sender } evaluator-data))
    )
)

;; Submit evaluation
(define-public (submit-evaluation 
    (manuscript-id uint) 
    (rating uint) 
    (comment-hash (string-ascii 64)))
    (let (
        (manuscript-data (unwrap! (map-get? Manuscripts { manuscript-id: manuscript-id }) ERR-MANUSCRIPT-NOT-FOUND))
        (evaluator-data (unwrap! (map-get? Evaluators { evaluator: tx-sender }) ERR-NOT-EVALUATOR))
    )
        (asserts! (> (len comment-hash) u0) ERR-EMPTY-HASH)
        (asserts! (and (>= rating u0) (<= rating u100)) ERR-INVALID-RATING)
        (asserts! (not (is-eq (get scholar manuscript-data) tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? Evaluations { manuscript-id: manuscript-id, evaluator: tx-sender })) ERR-ALREADY-EVALUATED)
        (asserts! (is-eq (get status evaluator-data) "active") ERR-NOT-AUTHORIZED)
        
        (map-set Evaluations 
            { manuscript-id: manuscript-id, evaluator: tx-sender }
            {
                rating: rating,
                comment-hash: comment-hash,
                timestamp: block-height,
                status: "submitted"
            }
        )
        
        (map-set Manuscripts
            { manuscript-id: manuscript-id }
            {
                scholar: (get scholar manuscript-data),
                ipfs-hash: (get ipfs-hash manuscript-data),
                status: "evaluated",
                evaluation-count: (+ (get evaluation-count manuscript-data) u1),
                total-rating: (+ (get total-rating manuscript-data) rating),
                timestamp: (get timestamp manuscript-data)
            }
        )
        
        (map-set Evaluators
            { evaluator: tx-sender }
            {
                collateral: (get collateral evaluator-data),
                evaluation-count: (+ (get evaluation-count evaluator-data) u1),
                credibility: (+ (get credibility evaluator-data) u1),
                status: (get status evaluator-data)
            }
        )
        
        (try! (stx-transfer? (var-get evaluation-honorarium) (as-contract tx-sender) tx-sender))
        (ok true)
    ))

;; Withdraw collateral tokens (only for paused or inactive evaluators)
(define-public (withdraw-collateral)
    (let (
        (evaluator-data (unwrap! (map-get? Evaluators { evaluator: tx-sender }) ERR-NOT-EVALUATOR))
    )
        (asserts! (or (is-eq (get status evaluator-data) "paused") 
                     (is-eq (get status evaluator-data) "inactive")) 
                 ERR-NOT-AUTHORIZED)
        
        (try! (stx-transfer? (get collateral evaluator-data) (as-contract tx-sender) tx-sender))
        (ok (map-delete Evaluators { evaluator: tx-sender }))
    )
)

;; Dispute an evaluation
(define-public (dispute-evaluation (manuscript-id uint) (evaluator principal) (reason (string-ascii 256)))
    (let (
        (evaluation-data (unwrap! (map-get? Evaluations { manuscript-id: manuscript-id, evaluator: evaluator }) ERR-MANUSCRIPT-NOT-FOUND))
        (dispute-stake (var-get min-collateral))
    )
        (asserts! (> (len reason) u0) ERR-EMPTY-REASON)
        (asserts! (not (is-eq evaluator tx-sender)) ERR-SELF-DISPUTE)
        (asserts! (>= (stx-get-balance tx-sender) dispute-stake) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? dispute-stake tx-sender (as-contract tx-sender)))
        
        (map-set Evaluations
            { manuscript-id: manuscript-id, evaluator: evaluator }
            {
                rating: (get rating evaluation-data),
                comment-hash: (get comment-hash evaluation-data),
                timestamp: (get timestamp evaluation-data),
                status: "disputed"
            }
        )
        (ok true)
    )
)

;; Update manuscript status
(define-public (update-manuscript-status (manuscript-id uint) (new-status (string-ascii 20)))
    (let (
        (manuscript-data (unwrap! (map-get? Manuscripts { manuscript-id: manuscript-id }) ERR-MANUSCRIPT-NOT-FOUND))
    )
        (asserts! (> (len new-status) u0) ERR-EMPTY-STATUS)
        (asserts! (or (is-eq new-status "pending") 
                     (is-eq new-status "evaluated")
                     (is-eq new-status "rejected")
                     (is-eq new-status "accepted")) ERR-INVALID-STATUS)
        (asserts! (is-eq tx-sender (get scholar manuscript-data)) ERR-NOT-AUTHORIZED)
        
        (ok (map-set Manuscripts
            { manuscript-id: manuscript-id }
            {
                scholar: (get scholar manuscript-data),
                ipfs-hash: (get ipfs-hash manuscript-data),
                status: new-status,
                evaluation-count: (get evaluation-count manuscript-data),
                total-rating: (get total-rating manuscript-data),
                timestamp: (get timestamp manuscript-data)
            }
        ))
    )
)

;; Read-only functions
(define-read-only (get-manuscript-details (manuscript-id uint))
    (map-get? Manuscripts { manuscript-id: manuscript-id })
)

(define-read-only (get-evaluation-details (manuscript-id uint) (evaluator principal))
    (map-get? Evaluations { manuscript-id: manuscript-id, evaluator: evaluator })
)

(define-read-only (get-evaluator-details (evaluator principal))
    (map-get? Evaluators { evaluator: evaluator })
)

(define-read-only (get-evaluator-earnings (evaluator principal))
    (match (map-get? Evaluators { evaluator: evaluator })
        evaluator-data (ok (* (get evaluation-count evaluator-data) (var-get evaluation-honorarium)))
        ERR-NOT-EVALUATOR)
)

;; Administrative functions
(define-public (update-protocol-settings 
    (new-min-collateral uint)
    (new-evaluation-honorarium uint))
    (begin
        (asserts! (is-protocol-admin) ERR-NOT-AUTHORIZED)
        (var-set min-collateral new-min-collateral)
        (var-set evaluation-honorarium new-evaluation-honorarium)
        (ok true)
    )
)

(define-public (pause-evaluator (evaluator principal))
    (let (
        (evaluator-data (unwrap! (map-get? Evaluators { evaluator: evaluator }) ERR-NOT-EVALUATOR))
    )
        (asserts! (is-protocol-admin) ERR-NOT-AUTHORIZED)
        (ok (map-set Evaluators
            { evaluator: evaluator }
            {
                collateral: (get collateral evaluator-data),
                evaluation-count: (get evaluation-count evaluator-data),
                credibility: (get credibility evaluator-data),
                status: "paused"
            }
        ))
    )
)