;; AI Model Licensing Marketplace Smart Contract
;; A decentralized platform enabling AI model creators to publish, license, and monetize 
;; their models through blockchain-based smart contracts with automated payments and 
;; transparent revenue distribution

;; Contract owner initialization
(define-constant contract-owner tx-sender)

;; Error codes for access control and authorization failures
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-ACCESS-DENIED (err u105))

;; Error codes for resource and data management
(define-constant ERR-RESOURCE-NOT-FOUND (err u101))
(define-constant ERR-DUPLICATE-RESOURCE (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u106))

;; Error codes for payment and financial operations
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-PAYMENT-TRANSFER-FAILED (err u108))

;; Error codes for license and service availability
(define-constant ERR-LICENSE-EXPIRED (err u104))
(define-constant ERR-SERVICE-UNAVAILABLE (err u107))

;; Platform commission configuration (250 = 2.5%)
(define-constant default-commission-rate u250)
(define-constant max-commission-rate u1000)
(define-constant commission-basis-points u10000)

;; License duration boundaries in blocks
(define-constant min-license-duration u144)
(define-constant max-license-duration u52560)

;; Model pricing and technical constraints
(define-constant min-license-price u1000)
(define-constant max-file-size u1000000000)
(define-constant max-accuracy-score u10000)

;; License transfer fee constant
(define-constant license-transfer-fee u50000)

;; Primary storage for AI model registry with core metadata
(define-map ai-models
  { model-id: uint }
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    duration: uint,
    is-active: bool,
    registered-at: uint,
    total-sales: uint
  }
)

;; License records tracking user access permissions and expiration
(define-map licenses
  { model-id: uint, holder: principal }
  {
    expires-at: uint,
    purchased-at: uint,
    amount-paid: uint,
    is-active: bool
  }
)

;; Technical metadata for AI models including version and file information
(define-map model-specs
  { model-id: uint }
  {
    version: (string-ascii 16),
    file-hash: (string-ascii 64),
    file-size: uint,
    accuracy: uint
  }
)

;; Financial analytics tracking revenue and license activity
(define-map model-earnings
  { model-id: uint }
  {
    total-revenue: uint,
    active-licenses: uint,
    platform-fees: uint
  }
)

;; Global marketplace state variables
(define-data-var next-model-id uint u1)
(define-data-var commission-rate uint default-commission-rate)
(define-data-var marketplace-active bool true)
(define-data-var total-volume uint u0)
(define-data-var total-models uint u0)

;; Retrieve complete information about a specific AI model
(define-read-only (get-model (model-id uint))
  (map-get? ai-models { model-id: model-id })
)

;; Retrieve license details for a specific user and model
(define-read-only (get-license (model-id uint) (holder principal))
  (map-get? licenses { model-id: model-id, holder: holder })
)

;; Retrieve technical specifications for a model
(define-read-only (get-specs (model-id uint))
  (map-get? model-specs { model-id: model-id })
)

;; Retrieve financial metrics for a model
(define-read-only (get-earnings (model-id uint))
  (map-get? model-earnings { model-id: model-id })
)

;; Check if a user currently holds a valid active license
(define-read-only (has-valid-license (model-id uint) (holder principal))
  (match (get-license model-id holder)
    license-data (and 
      (>= (get expires-at license-data) block-height) 
      (get is-active license-data))
    false
  )
)

;; Calculate platform commission for a given transaction amount
(define-read-only (calculate-commission (amount uint))
  (/ (* amount (var-get commission-rate)) commission-basis-points)
)

;; Retrieve comprehensive marketplace statistics
(define-read-only (get-stats)
  {
    total-models: (var-get total-models),
    total-volume: (var-get total-volume),
    commission-rate: (var-get commission-rate),
    marketplace-active: (var-get marketplace-active)
  }
)

;; Verify if caller has administrative privileges
(define-private (is-admin)
  (is-eq tx-sender contract-owner)
)

;; Verify if caller is the creator of a specific model
(define-private (is-model-creator (model-id uint))
  (match (get-model model-id)
    model-data (is-eq tx-sender (get creator model-data))
    false
  )
)

;; Validate that license duration falls within acceptable range
(define-private (is-valid-duration (duration uint))
  (and 
    (>= duration min-license-duration) 
    (<= duration max-license-duration))
)

;; Validate description string format and length constraints
(define-private (is-valid-description (desc (string-ascii 256)))
  (and 
    (> (len desc) u0) 
    (< (len desc) u257)
    (is-eq (len desc) (len (unwrap-panic (as-max-len? desc u256))))
  )
)

;; Validate title string format and length constraints
(define-private (is-valid-title (title (string-ascii 64)))
  (and 
    (> (len title) u0) 
    (< (len title) u65)
    (is-eq (len title) (len (unwrap-panic (as-max-len? title u64))))
  )
)

;; Validate file hash format (must be exactly 64 characters)
(define-private (is-valid-hash (hash (string-ascii 64)))
  (and 
    (is-eq (len hash) u64)
    (> (len hash) u0)
  )
)

;; Validate version string format and length
(define-private (is-valid-version (version (string-ascii 16)))
  (and 
    (> (len version) u0) 
    (< (len version) u17)
    (is-eq (len version) (len (unwrap-panic (as-max-len? version u16))))
  )
)

;; Validate file size is within acceptable limits
(define-private (is-valid-file-size (size uint))
  (and (> size u0) (<= size max-file-size))
)

;; Validate accuracy score is within bounds
(define-private (is-valid-accuracy (accuracy uint))
  (<= accuracy max-accuracy-score)
)

;; Validate model ID exists in the registry
(define-private (is-valid-model-id (model-id uint))
  (and 
    (> model-id u0) 
    (< model-id (var-get next-model-id))
  )
)

;; Update financial tracking for a model after a purchase
(define-private (record-revenue (model-id uint) (amount uint))
  (let (
    (current-earnings (default-to 
      { total-revenue: u0, active-licenses: u0, platform-fees: u0 }
      (get-earnings model-id)))
    (fee-amount (calculate-commission amount))
  )
    (map-set model-earnings
      { model-id: model-id }
      {
        total-revenue: (+ (get total-revenue current-earnings) amount),
        active-licenses: (+ (get active-licenses current-earnings) u1),
        platform-fees: (+ (get platform-fees current-earnings) fee-amount)
      }
    )
    (var-set total-volume (+ (var-get total-volume) amount))
  )
)

;; Register a new AI model in the marketplace with full metadata
(define-public (register-model
    (title (string-ascii 64))
    (description (string-ascii 256))
    (price uint)
    (duration uint)
    (version (string-ascii 16))
    (file-hash (string-ascii 64))
    (file-size uint)
    (accuracy uint))
  (let ((model-id (var-get next-model-id)))
    (asserts! (var-get marketplace-active) ERR-SERVICE-UNAVAILABLE)
    (asserts! (>= price min-license-price) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-duration duration) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-title title) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-description description) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-version version) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-hash file-hash) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-file-size file-size) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-accuracy accuracy) ERR-INVALID-PARAMETERS)
    
    (map-set ai-models
      { model-id: model-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        price: price,
        duration: duration,
        is-active: true,
        registered-at: block-height,
        total-sales: u0
      }
    )
    
    (map-set model-specs
      { model-id: model-id }
      {
        version: version,
        file-hash: file-hash,
        file-size: file-size,
        accuracy: accuracy
      }
    )
    
    (map-set model-earnings
      { model-id: model-id }
      { total-revenue: u0, active-licenses: u0, platform-fees: u0 }
    )
    
    (var-set next-model-id (+ model-id u1))
    (var-set total-models (+ (var-get total-models) u1))
    
    (ok model-id)
  )
)

;; Purchase a new license for an AI model
(define-public (buy-license (model-id uint))
  (let (
    (model-data (unwrap! (get-model model-id) ERR-RESOURCE-NOT-FOUND))
    (license-price (get price model-data))
    (platform-fee (calculate-commission license-price))
    (creator-amount (- license-price platform-fee))
    (expiration (+ block-height (get duration model-data)))
  )
    (asserts! (var-get marketplace-active) ERR-SERVICE-UNAVAILABLE)
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    (asserts! (get is-active model-data) ERR-SERVICE-UNAVAILABLE)
    (asserts! (not (has-valid-license model-id tx-sender)) ERR-DUPLICATE-RESOURCE)
    (asserts! (not (is-eq tx-sender (get creator model-data))) ERR-INVALID-PARAMETERS)
    
    (try! (stx-transfer? creator-amount tx-sender (get creator model-data)))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    
    (map-set licenses
      { model-id: model-id, holder: tx-sender }
      {
        expires-at: expiration,
        purchased-at: block-height,
        amount-paid: license-price,
        is-active: true
      }
    )
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { total-sales: (+ (get total-sales model-data) u1) })
    )
    
    (record-revenue model-id license-price)
    
    (ok expiration)
  )
)

;; Renew an existing license before or after expiration
(define-public (renew-license (model-id uint))
  (let (
    (model-data (unwrap! (get-model model-id) ERR-RESOURCE-NOT-FOUND))
    (license-data (unwrap! (get-license model-id tx-sender) ERR-RESOURCE-NOT-FOUND))
    (renewal-price (get price model-data))
    (platform-fee (calculate-commission renewal-price))
    (creator-amount (- renewal-price platform-fee))
    (new-expiration (+ block-height (get duration model-data)))
  )
    (asserts! (var-get marketplace-active) ERR-SERVICE-UNAVAILABLE)
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    (asserts! (get is-active model-data) ERR-SERVICE-UNAVAILABLE)
    (asserts! (get is-active license-data) ERR-LICENSE-EXPIRED)
    
    (try! (stx-transfer? creator-amount tx-sender (get creator model-data)))
    (try! (stx-transfer? platform-fee tx-sender contract-owner))
    
    (map-set licenses
      { model-id: model-id, holder: tx-sender }
      (merge license-data { expires-at: new-expiration })
    )
    
    (record-revenue model-id renewal-price)
    
    (ok new-expiration)
  )
)

;; Update model metadata (creator only)
(define-public (update-model
    (model-id uint)
    (title (string-ascii 64))
    (description (string-ascii 256))
    (price uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-model-creator model-id) ERR-ACCESS-DENIED)
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    (asserts! (>= price min-license-price) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-title title) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-description description) ERR-INVALID-PARAMETERS)
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data {
        title: title,
        description: description,
        price: price
      })
    )
    
    (ok true)
  )
)

;; Toggle model availability status (creator only)
(define-public (toggle-model (model-id uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-model-creator model-id) ERR-ACCESS-DENIED)
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { is-active: (not (get is-active model-data)) })
    )
    
    (ok (not (get is-active model-data)))
  )
)

;; Transfer license ownership to another user
(define-public (transfer-license (model-id uint) (new-holder principal))
  (let (
    (license-data (unwrap! (get-license model-id tx-sender) ERR-RESOURCE-NOT-FOUND))
  )
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    (asserts! (get is-active license-data) ERR-LICENSE-EXPIRED)
    (asserts! (>= (get expires-at license-data) block-height) ERR-LICENSE-EXPIRED)
    (asserts! (not (is-eq tx-sender new-holder)) ERR-INVALID-PARAMETERS)
    (asserts! (is-none (get-license model-id new-holder)) ERR-DUPLICATE-RESOURCE)
    
    (try! (stx-transfer? license-transfer-fee tx-sender contract-owner))
    
    (map-delete licenses { model-id: model-id, holder: tx-sender })
    (map-set licenses { model-id: model-id, holder: new-holder } license-data)
    
    (ok true)
  )
)

;; Batch verify licenses for multiple models
(define-public (batch-check-licenses (model-ids (list 5 uint)))
  (ok (map check-single-license model-ids))
)

;; Helper function for batch license verification
(define-private (check-single-license (model-id uint))
  {
    model-id: model-id,
    has-license: (has-valid-license model-id tx-sender)
  }
)

;; Get comprehensive analytics for a model
(define-read-only (get-model-analytics (model-id uint))
  (let (
    (model-data (get-model model-id))
    (earnings-data (get-earnings model-id))
    (specs-data (get-specs model-id))
  )
    (if (and (is-some model-data) (is-some earnings-data))
      (some {
        model-info: (unwrap-panic model-data),
        financial-data: (unwrap-panic earnings-data),
        technical-specs: specs-data,
        avg-revenue: (if (> (get total-sales (unwrap-panic model-data)) u0)
                        (/ (get total-revenue (unwrap-panic earnings-data))
                           (get total-sales (unwrap-panic model-data)))
                        u0)
      })
      none
    )
  )
)

;; Update platform commission rate (admin only)
(define-public (set-commission (new-rate uint))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= new-rate max-commission-rate) ERR-INVALID-PARAMETERS)
    (var-set commission-rate new-rate)
    (ok true)
  )
)

;; Toggle marketplace operational status (admin only)
(define-public (toggle-marketplace)
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED-ACCESS)
    (var-set marketplace-active (not (var-get marketplace-active)))
    (ok (var-get marketplace-active))
  )
)

;; Disable a model administratively (admin only)
(define-public (disable-model (model-id uint))
  (let ((model-data (unwrap! (get-model model-id) ERR-RESOURCE-NOT-FOUND)))
    (asserts! (is-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-model-id model-id) ERR-INVALID-PARAMETERS)
    
    (map-set ai-models
      { model-id: model-id }
      (merge model-data { is-active: false })
    )
    
    (ok true)
  )
)

;; Emergency withdrawal function for contract balance (admin only)
(define-public (withdraw (amount uint))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> amount u0) ERR-INVALID-PARAMETERS)
    (try! (stx-transfer? amount (as-contract tx-sender) contract-owner))
    (ok true)
  )
)

;; Comprehensive access control verification for a user and model
(define-read-only (check-access (model-id uint) (user principal))
  (let (
    (model-data (get-model model-id))
    (is-creator (if (is-some model-data) 
                   (is-eq user (get creator (unwrap-panic model-data))) 
                   false))
  )
    {
      model-exists: (is-some model-data),
      model-active: (if (is-some model-data) (get is-active (unwrap-panic model-data)) false),
      has-license: (has-valid-license model-id user),
      is-creator: is-creator,
      can-access: (or is-creator (has-valid-license model-id user))
    }
  )
)