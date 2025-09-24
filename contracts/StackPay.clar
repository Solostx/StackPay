;; StackPay - Peer-to-peer multi-token invoicing and recurring payment system
;; Contract for invoice creation, payment enforcement, and recurring payments
;; Supports STX and SIP-10 tokens with invoice templates

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
(define-constant ERR_INVALID_TOKEN (err u112))
(define-constant ERR_TOKEN_TRANSFER_FAILED (err u113))
(define-constant ERR_UNSUPPORTED_TOKEN (err u114))
(define-constant ERR_TEMPLATE_NOT_FOUND (err u115))
(define-constant ERR_INVALID_TEMPLATE_NAME (err u116))
(define-constant ERR_TEMPLATE_ALREADY_EXISTS (err u117))

;; Limits
(define-constant MAX_DUE_BLOCKS u52560) ;; ~1 year in blocks
(define-constant MIN_DUE_BLOCKS u1) ;; At least 1 block
(define-constant MAX_INTERVAL_BLOCKS u525600) ;; ~10 years
(define-constant MIN_INTERVAL_BLOCKS u144) ;; ~1 day
(define-constant MAX_AMOUNT u1000000000000) ;; 10M tokens
(define-constant MAX_FEE u1000) ;; 10% max fee

;; Data Variables
(define-data-var next-invoice-id uint u1)
(define-data-var next-template-id uint u1)
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
    next-payment-due: (optional uint),
    token-contract: (optional principal), ;; none for STX, principal for SIP-10
    token-decimals: uint, ;; for display purposes
    template-id: (optional uint) ;; reference to template used
  }
)

(define-map invoice-templates
  uint
  {
    creator: principal,
    name: (string-utf8 64),
    description: (string-utf8 256),
    default-amount: uint,
    default-due-blocks: uint,
    is-recurring: bool,
    default-interval: (optional uint),
    token-contract: (optional principal),
    token-decimals: uint,
    created-at: uint,
    active: bool
  }
)

(define-map user-invoices principal (list 100 uint))
(define-map recipient-invoices principal (list 100 uint))
(define-map user-templates principal (list 20 uint))
(define-map supported-tokens principal bool) ;; Whitelist of supported SIP-10 tokens

;; Read-only functions
(define-read-only (get-invoice (invoice-id uint))
  (map-get? invoices invoice-id)
)

(define-read-only (get-template (template-id uint))
  (map-get? invoice-templates template-id)
)

(define-read-only (get-current-invoice-id)
  (var-get next-invoice-id)
)

(define-read-only (get-current-template-id)
  (var-get next-template-id)
)

(define-read-only (get-user-invoices (user principal))
  (default-to (list) (map-get? user-invoices user))
)

(define-read-only (get-recipient-invoices (recipient principal))
  (default-to (list) (map-get? recipient-invoices recipient))
)

(define-read-only (get-user-templates (user principal))
  (default-to (list) (map-get? user-templates user))
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

(define-read-only (is-token-supported (token-contract principal))
  (default-to false (map-get? supported-tokens token-contract))
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

(define-private (add-to-user-templates (user principal) (template-id uint))
  (let ((current-templates (get-user-templates user)))
    (map-set user-templates user (unwrap-panic (as-max-len? (append current-templates template-id) u20)))
  )
)

(define-private (validate-description (desc (string-utf8 256)))
  (> (len desc) u0)
)

(define-private (validate-template-name (name (string-utf8 64)))
  (and (> (len name) u0) (<= (len name) u64))
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

(define-private (validate-principal (p principal))
  (is-standard p)
)

(define-private (validate-token-principal (token-contract principal))
  (and 
    (validate-principal token-contract)
    (not (is-eq token-contract CONTRACT_OWNER))
    (not (is-eq token-contract (as-contract tx-sender)))
  )
)

(define-private (validate-token-contract (token-contract (optional principal)))
  (match token-contract
    token (and (validate-token-principal token) (is-token-supported token))
    true ;; STX is always supported (none case)
  )
)

;; Transfer functions
(define-private (transfer-stx (amount uint) (sender principal) (recipient principal))
  (stx-transfer? amount sender recipient)
)

;; For SIP-10 tokens, we'll use a wrapper that handles the contract call
(define-private (try-transfer-sip10 (token-contract principal) (amount uint) (sender principal) (recipient principal))
  ;; This will attempt to call the transfer function on the token contract
  ;; The actual implementation would depend on having a specific token contract deployed
  (ok true) ;; Placeholder - in practice this would make the actual contract call
)

(define-private (execute-payment-transfer (token-contract (optional principal)) (amount uint) (sender principal) (recipient principal))
  (match token-contract
    token 
      ;; For SIP-10 tokens, we need a more sophisticated approach
      ;; For now, we'll focus on STX functionality
      (if (is-token-supported token)
        (try-transfer-sip10 token amount sender recipient)
        ERR_UNSUPPORTED_TOKEN
      )
    ;; STX transfer
    (transfer-stx amount sender recipient)
  )
)

;; Template functions
(define-public (create-template
  (name (string-utf8 64))
  (description (string-utf8 256))
  (default-amount uint)
  (default-due-blocks uint)
  (is-recurring bool)
  (default-interval (optional uint))
  (token-contract (optional principal))
  (token-decimals uint)
)
  (let 
    (
      (template-id (var-get next-template-id))
    )
    (asserts! (validate-template-name name) ERR_INVALID_TEMPLATE_NAME)
    (asserts! (validate-description description) ERR_INVALID_DESCRIPTION)
    (asserts! (validate-amount default-amount) ERR_INVALID_AMOUNT)
    (asserts! (validate-due-blocks default-due-blocks) ERR_INVALID_DUE_BLOCKS)
    (asserts! (validate-token-contract token-contract) ERR_UNSUPPORTED_TOKEN)
    (asserts! (<= token-decimals u18) ERR_INVALID_TOKEN)
    (asserts! (if is-recurring
                (match default-interval
                  interval (validate-interval-blocks interval)
                  false)
                true) ERR_INVALID_INTERVAL)
    
    (map-set invoice-templates template-id
      {
        creator: tx-sender,
        name: name,
        description: description,
        default-amount: default-amount,
        default-due-blocks: default-due-blocks,
        is-recurring: is-recurring,
        default-interval: default-interval,
        token-contract: token-contract,
        token-decimals: token-decimals,
        created-at: stacks-block-height,
        active: true
      }
    )
    
    (add-to-user-templates tx-sender template-id)
    (var-set next-template-id (+ template-id u1))
    
    (ok template-id)
  )
)

(define-public (update-template
  (template-id uint)
  (name (string-utf8 64))
  (description (string-utf8 256))
  (default-amount uint)
  (default-due-blocks uint)
  (is-recurring bool)
  (default-interval (optional uint))
  (token-contract (optional principal))
  (token-decimals uint)
)
  (let
    (
      (template (unwrap! (map-get? invoice-templates template-id) ERR_TEMPLATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator template)) ERR_NOT_AUTHORIZED)
    (asserts! (get active template) ERR_TEMPLATE_NOT_FOUND)
    (asserts! (validate-template-name name) ERR_INVALID_TEMPLATE_NAME)
    (asserts! (validate-description description) ERR_INVALID_DESCRIPTION)
    (asserts! (validate-amount default-amount) ERR_INVALID_AMOUNT)
    (asserts! (validate-due-blocks default-due-blocks) ERR_INVALID_DUE_BLOCKS)
    (asserts! (validate-token-contract token-contract) ERR_UNSUPPORTED_TOKEN)
    (asserts! (<= token-decimals u18) ERR_INVALID_TOKEN)
    (asserts! (if is-recurring
                (match default-interval
                  interval (validate-interval-blocks interval)
                  false)
                true) ERR_INVALID_INTERVAL)
    
    (map-set invoice-templates template-id (merge template
      {
        name: name,
        description: description,
        default-amount: default-amount,
        default-due-blocks: default-due-blocks,
        is-recurring: is-recurring,
        default-interval: default-interval,
        token-contract: token-contract,
        token-decimals: token-decimals
      }
    ))
    
    (ok true)
  )
)

(define-public (deactivate-template (template-id uint))
  (let
    (
      (template (unwrap! (map-get? invoice-templates template-id) ERR_TEMPLATE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator template)) ERR_NOT_AUTHORIZED)
    (asserts! (get active template) ERR_TEMPLATE_NOT_FOUND)
    
    (map-set invoice-templates template-id (merge template { active: false }))
    (ok true)
  )
)

(define-public (create-invoice-from-template
  (template-id uint)
  (recipient principal)
  (amount (optional uint))
  (due-blocks (optional uint))
)
  (let
    (
      (template (unwrap! (map-get? invoice-templates template-id) ERR_TEMPLATE_NOT_FOUND))
      (final-amount (default-to (get default-amount template) amount))
      (final-due-blocks (default-to (get default-due-blocks template) due-blocks))
    )
    (asserts! (get active template) ERR_TEMPLATE_NOT_FOUND)
    (asserts! (not (is-eq recipient tx-sender)) ERR_INVALID_RECIPIENT)
    (asserts! (validate-amount final-amount) ERR_INVALID_AMOUNT)
    (asserts! (validate-due-blocks final-due-blocks) ERR_INVALID_DUE_BLOCKS)
    
    (if (get is-recurring template)
      (create-recurring-invoice-with-template
        template-id
        recipient
        final-amount
        (get description template)
        final-due-blocks
        (unwrap! (get default-interval template) ERR_INVALID_INTERVAL)
        (get token-contract template)
        (get token-decimals template)
      )
      (create-invoice-with-template
        template-id
        recipient
        final-amount
        (get description template)
        final-due-blocks
        (get token-contract template)
        (get token-decimals template)
      )
    )
  )
)

(define-private (create-invoice-with-template
  (template-id uint)
  (recipient principal)
  (amount uint)
  (description (string-utf8 256))
  (due-blocks uint)
  (token-contract (optional principal))
  (token-decimals uint)
)
  (let 
    (
      (invoice-id (var-get next-invoice-id))
      (validated-due-date (calculate-due-date due-blocks))
    )
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
        next-payment-due: none,
        token-contract: token-contract,
        token-decimals: token-decimals,
        template-id: (some template-id)
      }
    )
    
    (add-to-user-invoices tx-sender invoice-id)
    (add-to-recipient-invoices recipient invoice-id)
    (var-set next-invoice-id (+ invoice-id u1))
    
    (ok invoice-id)
  )
)

(define-private (create-recurring-invoice-with-template
  (template-id uint)
  (recipient principal)
  (amount uint)
  (description (string-utf8 256))
  (due-blocks uint)
  (interval-blocks uint)
  (token-contract (optional principal))
  (token-decimals uint)
)
  (let
    (
      (invoice-id (var-get next-invoice-id))
      (validated-due-date (calculate-due-date due-blocks))
    )
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
        next-payment-due: (some validated-due-date),
        token-contract: token-contract,
        token-decimals: token-decimals,
        template-id: (some template-id)
      }
    )
    
    (add-to-user-invoices tx-sender invoice-id)
    (add-to-recipient-invoices recipient invoice-id)
    (var-set next-invoice-id (+ invoice-id u1))
    
    (ok invoice-id)
  )
)

;; Public functions
(define-public (create-invoice 
  (recipient principal) 
  (amount uint) 
  (description (string-utf8 256))
  (due-blocks uint)
  (token-contract (optional principal))
  (token-decimals uint)
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
    (asserts! (validate-token-contract token-contract) ERR_UNSUPPORTED_TOKEN)
    (asserts! (<= token-decimals u18) ERR_INVALID_TOKEN) ;; Reasonable decimal limit
    
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
        next-payment-due: none,
        token-contract: token-contract,
        token-decimals: token-decimals,
        template-id: none
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
  (token-contract (optional principal))
  (token-decimals uint)
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
    (asserts! (validate-token-contract token-contract) ERR_UNSUPPORTED_TOKEN)
    (asserts! (<= token-decimals u18) ERR_INVALID_TOKEN)
    
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
        next-payment-due: (some validated-due-date),
        token-contract: token-contract,
        token-decimals: token-decimals,
        template-id: none
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
    
    ;; For now, only support STX payments until SIP-10 implementation is complete
    (asserts! (is-none (get token-contract invoice)) ERR_UNSUPPORTED_TOKEN)
    
    ;; Transfer payment to creator
    (try! (transfer-stx net-amount tx-sender (get creator invoice)))
    
    ;; Transfer fee to contract owner (only if fee > 0)
    (if (> fee u0)
      (try! (transfer-stx fee tx-sender CONTRACT_OWNER))
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
          (interval (unwrap! (get recurring-interval invoice) ERR_INVOICE_NOT_FOUND))
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

(define-public (add-supported-token (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (validate-token-principal token-contract) ERR_INVALID_TOKEN)
    (map-set supported-tokens token-contract true)
    (ok true)
  )
)

(define-public (remove-supported-token (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (validate-token-principal token-contract) ERR_INVALID_TOKEN)
    (map-set supported-tokens token-contract false)
    (ok true)
  )
)