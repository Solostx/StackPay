;; StackPay - Peer-to-peer STX-based invoicing and recurring payment system
;; Contract for invoice creation, payment enforcement, and recurring payments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVOICE_NOT_FOUND (err u101))
(define-constant ERR_INVOICE_ALREADY_PAID (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_INVOICE_EXPIRED (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_INVALID_RECIPIENT (err u106))
(define-constant ERR_RECURRING_NOT_DUE (err u107))
(define-constant ERR_INVALID_INTERVAL (err u108))
(define-constant ERR_INVALID_DUE_BLOCKS (err u109))
(define-constant ERR_INVALID_DESCRIPTION (err u110))
(define-constant ERR_INVALID_FEE (err u111))

;; Limits
(define-constant MAX_DUE_BLOCKS u52560) ;; ~1 year in blocks
(define-constant MIN_DUE_BLOCKS u1) ;; At least 1 block
(define-constant MAX_INTERVAL_BLOCKS u525600) ;; ~10 years
(define-constant MIN_INTERVAL_BLOCKS u144) ;; ~1 day
(define-constant MAX_AMOUNT u1000000000000) ;; 10M STX
(define-constant MAX_FEE u1000) ;; 10% max fee

;; Data Variables
(define-data-var next-invoice-id uint u1)
(define-data-var contract-fees uint u50) ;; 0.5% fee in basis points

;; Data Maps
(define-map invoices
  uint
  {
    creator: principal,
    recipient: principal,
    amount: uint,
    description: (string-utf8 256),
    due-date: uint,
    paid: bool,
    paid-amount: uint,
    paid-at: (optional uint),
    created-at: uint,
    is-recurring: bool,
    recurring-interval: (optional uint), ;; in blocks
    next-payment-due: (optional uint)
  }
)

(define-map user-invoices principal (list 100 uint))
(define-map recipient-invoices principal (list 100 uint))

;; Read-only functions
(define-read-only (get-invoice (invoice-id uint))
  (map-get? invoices invoice-id)
)

(define-read-only (get-current-invoice-id)
  (var-get next-invoice-id)
)

(define-read-only (get-user-invoices (user principal))
  (default-to (list) (map-get? user-invoices user))
)

(define-read-only (get-recipient-invoices (recipient principal))
  (default-to (list) (map-get? recipient-invoices recipient))
)

(define-read-only (get-contract-fees)
  (var-get contract-fees)
)

(define-read-only (is-invoice-overdue (invoice-id uint))
  (match (map-get? invoices invoice-id)
    invoice (> stacks-block-height (get due-date invoice))
    false
  )
)

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get contract-fees)) u10000)
)

;; Private functions
(define-private (add-to-user-invoices (user principal) (invoice-id uint))
  (let ((current-invoices (get-user-invoices user)))
    (map-set user-invoices user (unwrap-panic (as-max-len? (append current-invoices invoice-id) u100)))
  )
)

(define-private (add-to-recipient-invoices (recipient principal) (invoice-id uint))
  (let ((current-invoices (get-recipient-invoices recipient)))
    (map-set recipient-invoices recipient (unwrap-panic (as-max-len? (append current-invoices invoice-id) u100)))
  )
)

(define-private (validate-description (desc (string-utf8 256)))
  (> (len desc) u0)
)

(define-private (validate-due-blocks (blocks uint))
  (and (>= blocks MIN_DUE_BLOCKS) (<= blocks MAX_DUE_BLOCKS))
)

(define-private (validate-interval-blocks (blocks uint))
  (and (>= blocks MIN_INTERVAL_BLOCKS) (<= blocks MAX_INTERVAL_BLOCKS))
)

(define-private (validate-amount (amount uint))
  (and (> amount u0) (<= amount MAX_AMOUNT))
)

(define-private (calculate-due-date (due-blocks uint))
  (+ stacks-block-height due-blocks)
)

;; Public functions
(define-public (create-invoice 
  (recipient principal) 
  (amount uint) 
  (description (string-utf8 256))
  (due-blocks uint)
)
  (let 
    (
      (invoice-id (var-get next-invoice-id))
      (validated-due-date (calculate-due-date due-blocks))
    )
    (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
    (asserts! (validate-description description) ERR_INVALID_DESCRIPTION)
    (asserts! (validate-due-blocks due-blocks) ERR_INVALID_DUE_BLOCKS)
    
    (map-set invoices invoice-id
      {
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        description: description,
        due-date: validated-due-date,
        paid: false,
        paid-amount: u0,
        paid-at: none,
        created-at: stacks-block-height,
        is-recurring: false,
        recurring-interval: none,
        next-payment-due: none
      }
    )
    
    (add-to-user-invoices tx-sender invoice-id)
    (add-to-recipient-invoices recipient invoice-id)
    (var-set next-invoice-id (+ invoice-id u1))
    
    (ok invoice-id)
  )
)

(define-public (create-recurring-invoice
  (recipient principal)
  (amount uint)
  (description (string-utf8 256))
  (due-blocks uint)
  (interval-blocks uint)
)
  (let
    (
      (invoice-id (var-get next-invoice-id))
      (validated-due-date (calculate-due-date due-blocks))
    )
    (asserts! (validate-amount amount) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
    (asserts! (validate-description description) ERR_INVALID_DESCRIPTION)
    (asserts! (validate-due-blocks due-blocks) ERR_INVALID_DUE_BLOCKS)
    (asserts! (validate-interval-blocks interval-blocks) ERR_INVALID_INTERVAL)
    
    (map-set invoices invoice-id
      {
        creator: tx-sender,
        recipient: recipient,
        amount: amount,
        description: description,
        due-date: validated-due-date,
        paid: false,
        paid-amount: u0,
        paid-at: none,
        created-at: stacks-block-height,
        is-recurring: true,
        recurring-interval: (some interval-blocks),
        next-payment-due: (some validated-due-date)
      }
    )
    
    (add-to-user-invoices tx-sender invoice-id)
    (add-to-recipient-invoices recipient invoice-id)
    (var-set next-invoice-id (+ invoice-id u1))
    
    (ok invoice-id)
  )
)

(define-public (pay-invoice (invoice-id uint))
  (let
    (
      (invoice (unwrap! (map-get? invoices invoice-id) ERR_INVOICE_NOT_FOUND))
      (fee (calculate-fee (get amount invoice)))
      (net-amount (- (get amount invoice) fee))
    )
    (asserts! (not (get paid invoice)) ERR_INVOICE_ALREADY_PAID)
    (asserts! (<= stacks-block-height (get due-date invoice)) ERR_INVOICE_EXPIRED)
    
    ;; Transfer payment to creator
    (try! (stx-transfer? net-amount tx-sender (get creator invoice)))
    
    ;; Transfer fee to contract owner
    (if (> fee u0)
      (try! (stx-transfer? fee tx-sender CONTRACT_OWNER))
      true
    )
    
    ;; Update invoice status
    (map-set invoices invoice-id (merge invoice {
      paid: true,
      paid-amount: (get amount invoice),
      paid-at: (some stacks-block-height)
    }))
    
    ;; Handle recurring payment
    (if (get is-recurring invoice)
              (let 
        (
          (interval (unwrap-panic (get recurring-interval invoice)))
          (validated-next-due (calculate-due-date interval))
        )
        (map-set invoices invoice-id (merge invoice {
          paid: false,
          paid-amount: u0,
          paid-at: none,
          due-date: validated-next-due,
          next-payment-due: (some validated-next-due)
        }))
      )
      true
    )
    
    (ok true)
  )
)

(define-public (pay-recurring-invoice (invoice-id uint))
  (let
    (
      (invoice (unwrap! (map-get? invoices invoice-id) ERR_INVOICE_NOT_FOUND))
      (next-due (unwrap! (get next-payment-due invoice) ERR_INVOICE_NOT_FOUND))
    )
    (asserts! (get is-recurring invoice) ERR_INVOICE_NOT_FOUND)
    (asserts! (<= next-due stacks-block-height) ERR_RECURRING_NOT_DUE)
    
    (pay-invoice invoice-id)
  )
)

(define-public (cancel-invoice (invoice-id uint))
  (let
    (
      (invoice (unwrap! (map-get? invoices invoice-id) ERR_INVOICE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator invoice)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get paid invoice)) ERR_INVOICE_ALREADY_PAID)
    
    (map-delete invoices invoice-id)
    (ok true)
  )
)

(define-public (update-contract-fees (new-fees uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fees MAX_FEE) ERR_INVALID_FEE)
    (var-set contract-fees new-fees)
    (ok true)
  )
)