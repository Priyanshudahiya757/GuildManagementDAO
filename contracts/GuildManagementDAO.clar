;; GuildManagement DAO Contract
;; A gaming guild coordination platform with profit sharing and automated tournament management
;; Two core functions: join-guild and distribute-profits

;; Define the Guild Management Token
;; Minimal GuildManagement DAO Contract

(define-fungible-token guild-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-guild-member (err u101))
(define-constant err-already-member (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-no-unclaimed (err u110))
(define-constant err-member-not-found (err u111))

;; State
(define-data-var total-members uint u0)
(define-data-var total-guild-balance uint u0)
(define-data-var membership-fee uint u1000)

(define-map guild-members principal {
    joined-at: uint,
    total-rewards: uint,
    is-active: bool
})

;; Distribution & accounting
(define-constant SCALE u1000000)
(define-data-var distribution-counter uint u0)
(define-map distributions uint uint)
(define-data-var cumulative-profit-per-token uint u0)
(define-map member-credit principal uint)

(define-public (join-guild)
    (let ((caller tx-sender) (fee (var-get membership-fee)))
        (begin
            (asserts! (is-none (map-get? guild-members caller)) err-already-member)
            (asserts! (>= (stx-get-balance caller) fee) err-insufficient-funds)
    (try! (stx-transfer? fee caller (as-contract tx-sender)))
            (map-set guild-members caller { joined-at: u0, total-rewards: u0, is-active: true })
    ;; initialize member credit so new members don't receive past distributions
    (map-set member-credit caller (var-get cumulative-profit-per-token))
            (var-set total-members (+ (var-get total-members) u1))
            (var-set total-guild-balance (+ (var-get total-guild-balance) fee))
            (try! (ft-mint? guild-token fee caller))
            (ok true)
        )
    )
)

(define-public (distribute-profits (profit-amount uint))
    (let ((caller tx-sender) (total-supply (ft-get-supply guild-token)))
        (begin
            (asserts! (is-eq caller contract-owner) err-owner-only)
            (asserts! (> profit-amount u0) err-invalid-amount)
            (asserts! (> total-supply u0) (err u105))
            ;; transfer STX from caller (owner) into the contract so claims can be paid
            (try! (stx-transfer? profit-amount caller (as-contract tx-sender)))
            (let ((next (+ (var-get distribution-counter) u1)) (per-token (/ (* profit-amount SCALE) total-supply)))
                (var-set distribution-counter next)
                (map-set distributions next profit-amount)
                (var-set cumulative-profit-per-token (+ (var-get cumulative-profit-per-token) per-token))
            )
            ;; track funds held by the contract
            (var-set total-guild-balance (+ (var-get total-guild-balance) profit-amount))
            (ok true)
        )
    )
)

(define-read-only (get-guild-info)
    (ok { total-members: (var-get total-members), guild-balance: (var-get total-guild-balance), membership-fee: (var-get membership-fee) })
)

(define-read-only (get-member-info (member principal))
    (ok (map-get? guild-members member))
)

(define-read-only (get-unclaimed-profits (member principal))
    (let ((m (map-get? guild-members member)))
        (if (is-none m)
                u0
                (let ((mc (map-get? member-credit member)) (cum (var-get cumulative-profit-per-token)) (balance (ft-get-balance guild-token member)))
                                (let ((credit (if (is-none mc) u0 (unwrap! mc u0))))
                                    (if (<= cum credit)
                                            u0
                                            (let ((delta (- cum credit)) (amount (/ (* delta balance) SCALE)))
                                                amount))))))
)

(define-public (claim-profits (member principal))
            (let ((caller tx-sender))
                (begin
                    (asserts! (is-eq caller member) err-not-guild-member)
                                        (let ((amount (get-unclaimed-profits member)))
                                            (begin
                                                (asserts! (> amount u0) err-no-unclaimed)
                                                ;; transfer STX from contract to member
                                                (try! (stx-transfer? amount (as-contract tx-sender) member))
                                                ;; update member credit and total rewards
                                                (map-set member-credit member (var-get cumulative-profit-per-token))
                                                                (let ((info (unwrap! (map-get? guild-members member) err-member-not-found)))
                                                                    (let ((old-joined (get joined-at info)) (old-total (get total-rewards info)) (old-active (get is-active info)))
                                                                        (map-set guild-members member { joined-at: old-joined, total-rewards: (+ old-total amount), is-active: old-active })
                                                                    )
                                                                                                                                )
                                                                                                (var-set total-guild-balance (- (var-get total-guild-balance) amount))
                                                (ok amount)
                                            )
                                        )
                )
            )
)

(define-read-only (get-my-unclaimed-profits)
    (get-unclaimed-profits tx-sender)
)