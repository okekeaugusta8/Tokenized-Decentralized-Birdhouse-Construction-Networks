;; Material Sourcing Contract
;; Manages wood and hardware procurement for birdhouse construction

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SUPPLIER_NOT_FOUND (err u201))
(define-constant ERR_MATERIAL_NOT_FOUND (err u202))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u203))
(define-constant ERR_INVALID_PRICE (err u204))

;; Data Variables
(define-data-var next-supplier-id uint u1)
(define-data-var next-material-id uint u1)
(define-data-var next-order-id uint u1)

;; Data Maps
(define-map suppliers
  { supplier-id: uint }
  {
    name: (string-ascii 100),
    owner: principal,
    location: (string-ascii 100),
    rating: uint,
    total-orders: uint,
    verified: bool,
    created-at: uint
  }
)

(define-map materials
  { material-id: uint }
  {
    supplier-id: uint,
    material-type: (string-ascii 50),
    wood-species: (string-ascii 30),
    dimensions: { length: uint, width: uint, thickness: uint },
    quantity-available: uint,
    price-per-unit: uint,
    quality-grade: (string-ascii 10),
    sustainable-certified: bool,
    created-at: uint
  }
)

(define-map orders
  { order-id: uint }
  {
    buyer: principal,
    supplier-id: uint,
    material-id: uint,
    quantity: uint,
    total-price: uint,
    status: (string-ascii 20),
    order-date: uint,
    delivery-date: (optional uint)
  }
)

(define-map supplier-ratings
  { supplier-id: uint, rater: principal }
  {
    rating: uint,
    comment: (string-ascii 200),
    order-id: uint,
    created-at: uint
  }
)

;; Public Functions

;; Register as a material supplier
(define-public (register-supplier
  (name (string-ascii 100))
  (location (string-ascii 100)))
  (let
    (
      (supplier-id (var-get next-supplier-id))
    )
    (map-set suppliers
      { supplier-id: supplier-id }
      {
        name: name,
        owner: tx-sender,
        location: location,
        rating: u0,
        total-orders: u0,
        verified: false,
        created-at: block-height
      }
    )

    (var-set next-supplier-id (+ supplier-id u1))
    (ok supplier-id)
  )
)

;; Add material listing
(define-public (add-material
  (supplier-id uint)
  (material-type (string-ascii 50))
  (wood-species (string-ascii 30))
  (length uint)
  (width uint)
  (thickness uint)
  (quantity-available uint)
  (price-per-unit uint)
  (quality-grade (string-ascii 10))
  (sustainable-certified bool))
  (let
    (
      (material-id (var-get next-material-id))
    )
    ;; Verify supplier ownership
    (match (map-get? suppliers { supplier-id: supplier-id })
      supplier
      (begin
        (asserts! (is-eq (get owner supplier) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (> price-per-unit u0) ERR_INVALID_PRICE)

        (map-set materials
          { material-id: material-id }
          {
            supplier-id: supplier-id,
            material-type: material-type,
            wood-species: wood-species,
            dimensions: { length: length, width: width, thickness: thickness },
            quantity-available: quantity-available,
            price-per-unit: price-per-unit,
            quality-grade: quality-grade,
            sustainable-certified: sustainable-certified,
            created-at: block-height
          }
        )

        (var-set next-material-id (+ material-id u1))
        (ok material-id)
      )
      ERR_SUPPLIER_NOT_FOUND
    )
  )
)

;; Place material order
(define-public (place-order (material-id uint) (quantity uint))
  (let
    (
      (order-id (var-get next-order-id))
    )
    (match (map-get? materials { material-id: material-id })
      material
      (begin
        (asserts! (>= (get quantity-available material) quantity) ERR_INSUFFICIENT_QUANTITY)

        (let
          (
            (total-price (* (get price-per-unit material) quantity))
          )
          ;; Create order
          (map-set orders
            { order-id: order-id }
            {
              buyer: tx-sender,
              supplier-id: (get supplier-id material),
              material-id: material-id,
              quantity: quantity,
              total-price: total-price,
              status: "pending",
              order-date: block-height,
              delivery-date: none
            }
          )

          ;; Update material quantity
          (map-set materials
            { material-id: material-id }
            (merge material { quantity-available: (- (get quantity-available material) quantity) })
          )

          (var-set next-order-id (+ order-id u1))
          (ok order-id)
        )
      )
      ERR_MATERIAL_NOT_FOUND
    )
  )
)

;; Update order status (supplier only)
(define-public (update-order-status
  (order-id uint)
  (new-status (string-ascii 20))
  (delivery-date (optional uint)))
  (match (map-get? orders { order-id: order-id })
    order
    (match (map-get? suppliers { supplier-id: (get supplier-id order) })
      supplier
      (begin
        (asserts! (is-eq (get owner supplier) tx-sender) ERR_UNAUTHORIZED)

        (map-set orders
          { order-id: order-id }
          (merge order { status: new-status, delivery-date: delivery-date })
        )

        ;; Update supplier stats if order completed
        (if (is-eq new-status "completed")
          (map-set suppliers
            { supplier-id: (get supplier-id order) }
            (merge supplier { total-orders: (+ (get total-orders supplier) u1) })
          )
          true
        )

        (ok true)
      )
      ERR_SUPPLIER_NOT_FOUND
    )
    ERR_MATERIAL_NOT_FOUND
  )
)

;; Rate supplier after order completion
(define-public (rate-supplier
  (supplier-id uint)
  (rating uint)
  (comment (string-ascii 200))
  (order-id uint))
  (begin
    ;; Validate rating range
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_UNAUTHORIZED)

    ;; Verify order exists and buyer is rating
    (match (map-get? orders { order-id: order-id })
      order
      (begin
        (asserts! (is-eq (get buyer order) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get supplier-id order) supplier-id) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status order) "completed") ERR_UNAUTHORIZED)

        (map-set supplier-ratings
          { supplier-id: supplier-id, rater: tx-sender }
          {
            rating: rating,
            comment: comment,
            order-id: order-id,
            created-at: block-height
          }
        )

        (ok true)
      )
      ERR_MATERIAL_NOT_FOUND
    )
  )
)

;; Verify supplier (admin only)
(define-public (verify-supplier (supplier-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? suppliers { supplier-id: supplier-id })
      supplier
      (begin
        (map-set suppliers
          { supplier-id: supplier-id }
          (merge supplier { verified: true })
        )
        (ok true)
      )
      ERR_SUPPLIER_NOT_FOUND
    )
  )
)

;; Read-only Functions

;; Get supplier details
(define-read-only (get-supplier (supplier-id uint))
  (map-get? suppliers { supplier-id: supplier-id })
)

;; Get material details
(define-read-only (get-material (material-id uint))
  (map-get? materials { material-id: material-id })
)

;; Get order details
(define-read-only (get-order (order-id uint))
  (map-get? orders { order-id: order-id })
)

;; Get supplier rating
(define-read-only (get-supplier-rating (supplier-id uint) (rater principal))
  (map-get? supplier-ratings { supplier-id: supplier-id, rater: rater })
)

;; Check if supplier is verified
(define-read-only (is-supplier-verified (supplier-id uint))
  (match (map-get? suppliers { supplier-id: supplier-id })
    supplier (get verified supplier)
    false
  )
)

;; Get material availability
(define-read-only (get-material-availability (material-id uint))
  (match (map-get? materials { material-id: material-id })
    material (get quantity-available material)
    u0
  )
)
