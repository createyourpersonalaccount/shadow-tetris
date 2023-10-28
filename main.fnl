(import-macros {: var* : local*} :macros)

(local* lume
        "A collection of functions for Lua, geared towards game development.
See <https://github.com/rxi/lume>."
        (require :lume))

(local* bump
        "Lua collision-detection library for axis-aligned rectangles.
See <https://github.com/kikito/bump.lua>."
        (require :bump))

(local* px
        "The number of pixels in a block side."
        32)

(local* width
        "The width of the tetris board, in blocks."
        10)

(local* height
        "The height of the tetris board, in blocks."
        20)

(local* origin
        "The origin of the tetris board, in blocks."
        [0 0])

(local* tetris-shapes
        "The available tetris shapes.

The coordinates are in game coordinates (Y grows downwards).  The
coordinate units are blocks, and coordinates start from 0.

The upper rightmost block has the [0 0] coordinates."
        [ [[0 0] [0 1] [1 1] [1 2]]    ; S-tetromino
          [[0 0] [0 1] [1 1] [1 0]]    ; O-tetromino
          [[0 0] [0 1] [0 2] [1 0]]    ; L-tetromino
          [[0 0] [0 1] [0 2] [0 3]]    ; I-tetromino
          [[0 0] [1 0] [2 0] [1 1]]    ; T-tetromino
          [[0 0] [1 0] [1 1] [2 1]]    ; Z-tetromino
        ])

(var* shadow-block
      "The shadow block falling from above.")

(local* shadow-block-movement-delta
        "The shadow block is updated every SHADOW-BLOCK-MOVEMENT-DELTA seconds."
        1.0)

(local* player-movement-delta
        "The player input is updated every PLAYER-MOVEMENT-DELTA seconds."
        0.1)

(var* pile-movement-delta
      "The pile is growing every PILE-MOVEMENT-DELTA seconds. This is variable."
      2)

(fn create-timer []
  "Returns a timer closure. The timer can be reset if the value 0 is passed to it.

Example usage:

    (let [f (timer)]
      (print (f))
      (print (f))
      (f 0) ; reset the timer
      (print (f)))"
  (var* start
        "Keeps track of the time stamp of the previous call."
        (love.timer.getTime))
  (fn [reset]
    (if (= reset 0)
        (do (set start (love.timer.getTime))
            0)
        (- (love.timer.getTime) start))))

(var* game-timer
        "The game timer. It should never be reset."
        (create-timer))

(var* player-timer
        "The player timer. It is reset every time a player action occurs."
        (create-timer))

(var* shadow-block-timer
      "The shadow block timer. It is reset every time the shadow block moves."
      (create-timer))

(var* pile-timer
        "The pile timer. It is reset every time the pile moves up."
        (create-timer))

(var* last-key
      "The last key pressed by the player. When processed, it is reset to the
value nil.")

(fn love.load []
  "One-time setup."
  (math.randomseed (os.time))
  (love.keyboard.setKeyRepeat true)
  (set shadow-block
       {:coordinates [4 0]
        :shape (lume.randomchoice tetris-shapes)
        :get-coordinates (lambda [self]
                           "Obtain the :SHAPE coordinates relative to :COORDINATES."
                          (let [[x0 y0] self.coordinates]
                            (lume.map shadow-block.shape
                                      (lambda [[x y]]
                                        [(+ x x0) (+ y y0)]))))
        }))

(fn move-block [block direction]
  "Move the BLOCK one unit in the given DIRECTION."
  (let [[x y] block.coordinates]
    (set block.coordinates
         (case direction
           :down [x (+ y 1)]
           :right [(+ x 1) y]
           :left [(- x 1) y]
           :up [x (- y 1)]))))

(fn left-wall-collision? []
  "Returns true if the SHADOW-BLOCK collides with the left wall."
  (lume.any (shadow-block:get-coordinates)
            (lambda [[x y]] (= x 0))))

(fn right-wall-collision? []
  "Returns true if the SHADOW-BLOCK collides with the right wall."
  (lume.any (shadow-block:get-coordinates)
            (lambda [[x y]] (= x (- width 1)))))

(fn process-last-key []
  "Process LAST-KEY, the last key pressed by the user."
  (case last-key
    :down (move-block shadow-block :down)
    :left (if (not (left-wall-collision?))
              (move-block shadow-block :left))
    :right (if (not (right-wall-collision?))
               (move-block shadow-block :right)))
  (set last-key nil))

(fn reset-timer [timer]
  "Reset a timer closure."
  (timer 0))

(fn love.update []
  "Callback for updating frame before drawing"
  (if (< player-movement-delta (player-timer))
      (do (process-last-key)
          (reset-timer player-timer)))
  (if (< shadow-block-movement-delta (shadow-block-timer))
      (do (move-block shadow-block :down)
          (reset-timer shadow-block-timer))))

(fn block->px [n]
  "Converts N block units to number of pixels."
  (* px n))

(fn love.draw []
  "Callback when drawing."
  ;; draw a separating barrier
  (love.graphics.line (+ 1 (block->px width)) 0
                      (+ 1 (block->px width)) (block->px height))
  ;; draw the shadow-block
  (lume.map (shadow-block:get-coordinates)
            (lambda [[x y]] (love.graphics.rectangle "fill" (block->px x)
                                                     (block->px y) px px))))

(fn kbd [keys]
  "A closure that evaluates to false if its argument is not included in KEYS."
  (lambda [k]
    (lume.find keys k)))

(var* keybindings
      "The keybindings for the video game.

The entries of this table are of the form

    (kbd KEYS) FUNC

where KEYS is a sequential table of keys and FUNC is the action to be
taken if the pressed key is one of KEYS. FUNC should accept an
argument which is the pressed key."
      { (kbd [:q :escape]) (lambda [k] (love.event.quit 0))
        (kbd [:up :down :left :right]) (lambda [k] (set last-key k)) })

(fn love.keypressed [k]
  "Callback when key is pressed. Looks up the key in KEYBINDINGS."
  (each [keys action (pairs keybindings)]
    (if (keys k) (action k))))

