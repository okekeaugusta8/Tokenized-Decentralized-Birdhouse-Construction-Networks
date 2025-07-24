;; Assembly Coordination Contract
;; Organizes community birdhouse building workshops

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_WORKSHOP_NOT_FOUND (err u301))
(define-constant ERR_WORKSHOP_FULL (err u302))
(define-constant ERR_ALREADY_REGISTERED (err u303))
(define-constant ERR_WORKSHOP_PAST (err u304))
(define-constant ERR_NOT_REGISTERED (err u305))

;; Data Variables
(define-data-var next-workshop-id uint u1)
(define-data-var next-participant-id uint u1)

;; Data Maps
(define-map workshops
  { workshop-id: uint }
  {
    organizer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    location: (string-ascii 100),
    date: uint,
    duration-hours: uint,
    max-participants: uint,
    current-participants: uint,
    skill-level: (string-ascii 20),
    materials-provided: bool,
    tools-provided: bool,
    cost: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map workshop-participants
  { workshop-id: uint, participant: principal }
  {
    registration-date: uint,
    skill-level: (string-ascii 20),
    tools-bringing: (list 10 (string-ascii 30)),
    special-requirements: (string-ascii 200),
    attended: bool,
    rating: (optional uint)
  }
)

(define-map participant-profiles
  { participant: principal }
  {
    name: (string-ascii 100),
    skill-level: (string-ascii 20),
    workshops-attended: uint,
    workshops-organized: uint,
    total-rating: uint,
    rating-count: uint,
    tools-owned: (list 20 (string-ascii 30)),
    created-at: uint
  }
)

(define-map workshop-feedback
  { workshop-id: uint, participant: principal }
  {
    rating: uint,
    comment: (string-ascii 300),
    would-recommend: bool,
    created-at: uint
  }
)

;; Public Functions

;; Create a new workshop
(define-public (create-workshop
  (title (string-ascii 100))
  (description (string-ascii 500))
  (location (string-ascii 100))
  (date uint)
  (duration-hours uint)
  (max-participants uint)
  (skill-level (string-ascii 20))
  (materials-provided bool)
  (tools-provided bool)
  (cost uint))
  (let
    (
      (workshop-id (var-get next-workshop-id))
    )
    ;; Ensure workshop is in the future
    (asserts! (> date block-height) ERR_WORKSHOP_PAST)

    (map-set workshops
      { workshop-id: workshop-id }
      {
        organizer: tx-sender,
        title: title,
        description: description,
        location: location,
        date: date,
        duration-hours: duration-hours,
        max-participants: max-participants,
        current-participants: u0,
        skill-level: skill-level,
        materials-provided: materials-provided,
        tools-provided: tools-provided,
        cost: cost,
        status: "scheduled",
        created-at: block-height
      }
    )

    ;; Update organizer profile
    (update-participant-profile tx-sender u0 u1)

    (var-set next-workshop-id (+ workshop-id u1))
    (ok workshop-id)
  )
)

;; Register for a workshop
(define-public (register-for-workshop
  (workshop-id uint)
  (skill-level (string-ascii 20))
  (tools-bringing (list 10 (string-ascii 30)))
  (special-requirements (string-ascii 200)))
  (match (map-get? workshops { workshop-id: workshop-id })
    workshop
    (begin
      ;; Check if workshop is not full
      (asserts! (< (get current-participants workshop) (get max-participants workshop)) ERR_WORKSHOP_FULL)

      ;; Check if not already registered
      (asserts! (is-none (map-get? workshop-participants { workshop-id: workshop-id, participant: tx-sender })) ERR_ALREADY_REGISTERED)

      ;; Check if workshop is in the future
      (asserts! (> (get date workshop) block-height) ERR_WORKSHOP_PAST)

      ;; Register participant
      (map-set workshop-participants
        { workshop-id: workshop-id, participant: tx-sender }
        {
          registration-date: block-height,
          skill-level: skill-level,
          tools-bringing: tools-bringing,
          special-requirements: special-requirements,
          attended: false,
          rating: none
        }
      )

      ;; Update workshop participant count
      (map-set workshops
        { workshop-id: workshop-id }
        (merge workshop { current-participants: (+ (get current-participants workshop) u1) })
      )

      (ok true)
    )
    ERR_WORKSHOP_NOT_FOUND
  )
)

;; Mark attendance (organizer only)
(define-public (mark-attendance (workshop-id uint) (participant principal) (attended bool))
  (match (map-get? workshops { workshop-id: workshop-id })
    workshop
    (begin
      (asserts! (is-eq (get organizer workshop) tx-sender) ERR_UNAUTHORIZED)

      (match (map-get? workshop-participants { workshop-id: workshop-id, participant: participant })
        registration
        (begin
          (map-set workshop-participants
            { workshop-id: workshop-id, participant: participant }
            (merge registration { attended: attended })
          )

          ;; Update participant profile if attended
          (if attended
            (update-participant-profile participant u1 u0)
            true
          )

          (ok true)
        )
        ERR_NOT_REGISTERED
      )
    )
    ERR_WORKSHOP_NOT_FOUND
  )
)

;; Submit workshop feedback
(define-public (submit-feedback
  (workshop-id uint)
  (rating uint)
  (comment (string-ascii 300))
  (would-recommend bool))
  (begin
    ;; Validate rating
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_UNAUTHORIZED)

    ;; Check if participant was registered and attended
    (match (map-get? workshop-participants { workshop-id: workshop-id, participant: tx-sender })
      registration
      (begin
        (asserts! (get attended registration) ERR_UNAUTHORIZED)

        (map-set workshop-feedback
          { workshop-id: workshop-id, participant: tx-sender }
          {
            rating: rating,
            comment: comment,
            would-recommend: would-recommend,
            created-at: block-height
          }
        )

        (ok true)
      )
      ERR_NOT_REGISTERED
    )
  )
)

;; Update workshop status (organizer only)
(define-public (update-workshop-status (workshop-id uint) (new-status (string-ascii 20)))
  (match (map-get? workshops { workshop-id: workshop-id })
    workshop
    (begin
      (asserts! (is-eq (get organizer workshop) tx-sender) ERR_UNAUTHORIZED)

      (map-set workshops
        { workshop-id: workshop-id }
        (merge workshop { status: new-status })
      )

      (ok true)
    )
    ERR_WORKSHOP_NOT_FOUND
  )
)

;; Create participant profile
(define-public (create-participant-profile
  (name (string-ascii 100))
  (skill-level (string-ascii 20))
  (tools-owned (list 20 (string-ascii 30))))
  (begin
    (map-set participant-profiles
      { participant: tx-sender }
      {
        name: name,
        skill-level: skill-level,
        workshops-attended: u0,
        workshops-organized: u0,
        total-rating: u0,
        rating-count: u0,
        tools-owned: tools-owned,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get workshop details
(define-read-only (get-workshop (workshop-id uint))
  (map-get? workshops { workshop-id: workshop-id })
)

;; Get participant registration
(define-read-only (get-participant-registration (workshop-id uint) (participant principal))
  (map-get? workshop-participants { workshop-id: workshop-id, participant: participant })
)

;; Get participant profile
(define-read-only (get-participant-profile (participant principal))
  (map-get? participant-profiles { participant: participant })
)

;; Get workshop feedback
(define-read-only (get-workshop-feedback (workshop-id uint) (participant principal))
  (map-get? workshop-feedback { workshop-id: workshop-id, participant: participant })
)

;; Check if workshop has space
(define-read-only (has-workshop-space (workshop-id uint))
  (match (map-get? workshops { workshop-id: workshop-id })
    workshop (< (get current-participants workshop) (get max-participants workshop))
    false
  )
)

;; Private Functions

;; Update participant profile stats
(define-private (update-participant-profile (participant principal) (attended-increment uint) (organized-increment uint))
  (let
    (
      (current-profile (default-to
        { name: "", skill-level: "beginner", workshops-attended: u0, workshops-organized: u0,
          total-rating: u0, rating-count: u0, tools-owned: (list), created-at: block-height }
        (map-get? participant-profiles { participant: participant })
      ))
    )
    (map-set participant-profiles
      { participant: participant }
      (merge current-profile {
        workshops-attended: (+ (get workshops-attended current-profile) attended-increment),
        workshops-organized: (+ (get workshops-organized current-profile) organized-increment)
      })
    )
  )
)
