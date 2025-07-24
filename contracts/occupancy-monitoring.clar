;; Occupancy Monitoring Contract
;; Tracks bird usage and nesting success rates

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_INSTALLATION_NOT_FOUND (err u501))
(define-constant ERR_OBSERVATION_NOT_FOUND (err u502))
(define-constant ERR_INVALID_DATE (err u503))
(define-constant ERR_INVALID_COUNT (err u504))
(define-constant ERR_SEASON_NOT_FOUND (err u505))

;; Data Variables
(define-data-var next-observation-id uint u1)
(define-data-var next-season-id uint u1)
(define-data-var current-breeding-season uint u1)

;; Data Maps
(define-map occupancy-observations
  { observation-id: uint }
  {
    installation-id: uint,
    observer: principal,
    observation-date: uint,
    species-observed: (string-ascii 50),
    activity-type: (string-ascii 30),
    bird-count: uint,
    nesting-stage: (string-ascii 20),
    eggs-count: (optional uint),
    chicks-count: (optional uint),
    behavior-notes: (string-ascii 300),
    weather-conditions: (string-ascii 100),
    verified: bool,
    created-at: uint
  }
)

(define-map breeding-seasons
  { season-id: uint }
  {
    installation-id: uint,
    species: (string-ascii 50),
    season-start: uint,
    season-end: (optional uint),
    total-eggs: uint,
    total-hatched: uint,
    total-fledged: uint,
    success-rate: uint,
    abandonment-reason: (optional (string-ascii 100)),
    completed: bool
  }
)

(define-map installation-statistics
  { installation-id: uint }
  {
    total-observations: uint,
    unique-species: uint,
    successful-broods: uint,
    total-broods: uint,
    average-success-rate: uint,
    last-occupied: (optional uint),
    most-common-species: (optional (string-ascii 50)),
    peak-activity-month: (optional uint)
  }
)

(define-map observer-profiles
  { observer: principal }
  {
    name: (string-ascii 100),
    experience-level: (string-ascii 20),
    total-observations: uint,
    verified-observations: uint,
    accuracy-rating: uint,
    specialization: (list 5 (string-ascii 50)),
    equipment-owned: (list 10 (string-ascii 50)),
    created-at: uint
  }
)

(define-map species-data
  { species: (string-ascii 50) }
  {
    total-installations-used: uint,
    total-successful-broods: uint,
    average-eggs-per-brood: uint,
    average-success-rate: uint,
    peak-breeding-months: (list 3 uint),
    habitat-preferences: (list 5 (string-ascii 50))
  }
)

;; Public Functions

;; Record occupancy observation
(define-public (record-observation
  (installation-id uint)
  (species-observed (string-ascii 50))
  (activity-type (string-ascii 30))
  (bird-count uint)
  (nesting-stage (string-ascii 20))
  (eggs-count (optional uint))
  (chicks-count (optional uint))
  (behavior-notes (string-ascii 300))
  (weather-conditions (string-ascii 100)))
  (let
    (
      (observation-id (var-get next-observation-id))
    )
    (asserts! (<= bird-count u20) ERR_INVALID_COUNT)

    (map-set occupancy-observations
      { observation-id: observation-id }
      {
        installation-id: installation-id,
        observer: tx-sender,
        observation-date: block-height,
        species-observed: species-observed,
        activity-type: activity-type,
        bird-count: bird-count,
        nesting-stage: nesting-stage,
        eggs-count: eggs-count,
        chicks-count: chicks-count,
        behavior-notes: behavior-notes,
        weather-conditions: weather-conditions,
        verified: false,
        created-at: block-height
      }
    )

    ;; Update observer profile
    (update-observer-stats tx-sender u1 u0)

    ;; Update installation statistics
    (update-installation-stats installation-id species-observed)

    (var-set next-observation-id (+ observation-id u1))
    (ok observation-id)
  )
)

;; Start breeding season tracking
(define-public (start-breeding-season
  (installation-id uint)
  (species (string-ascii 50)))
  (let
    (
      (season-id (var-get next-season-id))
    )
    (map-set breeding-seasons
      { season-id: season-id }
      {
        installation-id: installation-id,
        species: species,
        season-start: block-height,
        season-end: none,
        total-eggs: u0,
        total-hatched: u0,
        total-fledged: u0,
        success-rate: u0,
        abandonment-reason: none,
        completed: false
      }
    )

    (var-set next-season-id (+ season-id u1))
    (var-set current-breeding-season season-id)
    (ok season-id)
  )
)

;; Update breeding season progress
(define-public (update-breeding-season
  (season-id uint)
  (total-eggs uint)
  (total-hatched uint)
  (total-fledged uint)
  (abandonment-reason (optional (string-ascii 100))))
  (match (map-get? breeding-seasons { season-id: season-id })
    season
    (let
      (
        (success-rate (if (> total-eggs u0)
          (/ (* total-fledged u100) total-eggs)
          u0))
      )
      (map-set breeding-seasons
        { season-id: season-id }
        (merge season {
          total-eggs: total-eggs,
          total-hatched: total-hatched,
          total-fledged: total-fledged,
          success-rate: success-rate,
          abandonment-reason: abandonment-reason
        })
      )

      (ok true)
    )
    ERR_SEASON_NOT_FOUND
  )
)

;; Complete breeding season
(define-public (complete-breeding-season (season-id uint))
  (match (map-get? breeding-seasons { season-id: season-id })
    season
    (begin
      (map-set breeding-seasons
        { season-id: season-id }
        (merge season {
          season-end: (some block-height),
          completed: true
        })
      )

      ;; Update species data
      (update-species-data (get species season) (get total-eggs season) (get success-rate season))

      (ok true)
    )
    ERR_SEASON_NOT_FOUND
  )
)

;; Verify observation (admin or experienced observer)
(define-public (verify-observation (observation-id uint))
  (let
    (
      (is-admin (is-eq tx-sender CONTRACT_OWNER))
      (observer-profile (map-get? observer-profiles { observer: tx-sender }))
      (is-experienced (match observer-profile
        profile (>= (get accuracy-rating profile) u80)
        false))
    )
    (asserts! (or is-admin is-experienced) ERR_UNAUTHORIZED)

    (match (map-get? occupancy-observations { observation-id: observation-id })
      observation
      (begin
        (map-set occupancy-observations
          { observation-id: observation-id }
          (merge observation { verified: true })
        )

        ;; Update observer stats if verified by admin
        (if is-admin
          (update-observer-stats (get observer observation) u0 u1)
          true
        )

        (ok true)
      )
      ERR_OBSERVATION_NOT_FOUND
    )
  )
)

;; Create observer profile
(define-public (create-observer-profile
  (name (string-ascii 100))
  (experience-level (string-ascii 20))
  (specialization (list 5 (string-ascii 50)))
  (equipment-owned (list 10 (string-ascii 50))))
  (begin
    (map-set observer-profiles
      { observer: tx-sender }
      {
        name: name,
        experience-level: experience-level,
        total-observations: u0,
        verified-observations: u0,
        accuracy-rating: u50,
        specialization: specialization,
        equipment-owned: equipment-owned,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Generate occupancy report
(define-public (generate-occupancy-report (installation-id uint))
  (match (map-get? installation-statistics { installation-id: installation-id })
    stats
    (ok {
      installation-id: installation-id,
      total-observations: (get total-observations stats),
      unique-species: (get unique-species stats),
      success-rate: (get average-success-rate stats),
      most-active-species: (get most-common-species stats),
      last-activity: (get last-occupied stats)
    })
    ERR_INSTALLATION_NOT_FOUND
  )
)

;; Read-only Functions

;; Get observation details
(define-read-only (get-observation (observation-id uint))
  (map-get? occupancy-observations { observation-id: observation-id })
)

;; Get breeding season details
(define-read-only (get-breeding-season (season-id uint))
  (map-get? breeding-seasons { season-id: season-id })
)

;; Get installation statistics
(define-read-only (get-installation-stats (installation-id uint))
  (map-get? installation-statistics { installation-id: installation-id })
)

;; Get observer profile
(define-read-only (get-observer-profile (observer principal))
  (map-get? observer-profiles { observer: observer })
)

;; Get species data
(define-read-only (get-species-data (species (string-ascii 50)))
  (map-get? species-data { species: species })
)

;; Calculate success rate for installation
(define-read-only (calculate-success-rate (installation-id uint))
  (match (map-get? installation-statistics { installation-id: installation-id })
    stats
    (if (> (get total-broods stats) u0)
      (/ (* (get successful-broods stats) u100) (get total-broods stats))
      u0)
    u0
  )
)

;; Private Functions

;; Update observer statistics
(define-private (update-observer-stats (observer principal) (observations-increment uint) (verified-increment uint))
  (let
    (
      (current-profile (default-to
        { name: "", experience-level: "beginner", total-observations: u0, verified-observations: u0,
          accuracy-rating: u50, specialization: (list), equipment-owned: (list), created-at: block-height }
        (map-get? observer-profiles { observer: observer })
      ))
    )
    (let
      (
        (new-total (+ (get total-observations current-profile) observations-increment))
        (new-verified (+ (get verified-observations current-profile) verified-increment))
        (new-accuracy (if (> new-total u0) (/ (* new-verified u100) new-total) u50))
      )
      (map-set observer-profiles
        { observer: observer }
        (merge current-profile {
          total-observations: new-total,
          verified-observations: new-verified,
          accuracy-rating: new-accuracy
        })
      )
    )
  )
)

;; Update installation statistics
(define-private (update-installation-stats (installation-id uint) (species (string-ascii 50)))
  (let
    (
      (current-stats (default-to
        { total-observations: u0, unique-species: u0, successful-broods: u0, total-broods: u0,
          average-success-rate: u0, last-occupied: none, most-common-species: none, peak-activity-month: none }
        (map-get? installation-statistics { installation-id: installation-id })
      ))
    )
    (map-set installation-statistics
      { installation-id: installation-id }
      (merge current-stats {
        total-observations: (+ (get total-observations current-stats) u1),
        last-occupied: (some block-height),
        most-common-species: (some species)
      })
    )
  )
)

;; Update species data
(define-private (update-species-data (species (string-ascii 50)) (eggs uint) (success-rate uint))
  (let
    (
      (current-data (default-to
        { total-installations-used: u0, total-successful-broods: u0, average-eggs-per-brood: u0,
          average-success-rate: u0, peak-breeding-months: (list), habitat-preferences: (list) }
        (map-get? species-data { species: species })
      ))
    )
    (map-set species-data
      { species: species }
      (merge current-data {
        total-installations-used: (+ (get total-installations-used current-data) u1),
        total-successful-broods: (+ (get total-successful-broods current-data) (if (> success-rate u50) u1 u0)),
        average-eggs-per-brood: eggs
      })
    )
  )
)
