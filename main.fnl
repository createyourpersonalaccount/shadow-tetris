(import-macros {: var* : local*} :macros)

(local* lume
        "A collection of functions for Lua, geared towards game development.

See <https://github.com/rxi/lume>."
        (require :lume))

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

(var* game-state
      "The game state, one of :menu or :game."
      nil)

(var* pile-blocks
      "The blocks in the pile, initially empty."
      [])

(var* score
      "The total number of blocks that have vanished plus bonus for
reaching bottom."
      nil)

(var* music
      "The soundtrack.

By composer and music producer Kevin MacLeod. Find a lot more of his
excellent music (for free!) here, <https://incompetech.com/>.  This
track is not necessarily representative of the rest of his work."
      nil)

(fn create-timer []
  "Returns a timer closure.

The timer can be reset if the value 0 is passed to it.

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

(var* music-timer
      "The music timer. The music loops every 1 minute."
      (create-timer))

(var* game-timer
        "The game timer. It should never be reset."
        (create-timer))

(var* player-timer
        "The player timer. It is reset every time a player action
occurs."
        (create-timer))

(var* shadow-block-timer
      "The shadow block timer. It is reset every time the shadow block
moves."
      (create-timer))

(var* pile-timer
        "The pile timer. It is reset every time the pile moves up."
        (create-timer))

(local* particle-spawn-time
        "The time it takes for a particle to spawn."
        0.01)

(var* particle-timer
      "The particle timer. It is reset every PARTICLE-SPAWN-TIME."
      (create-timer))

(local* red-color "The color red." [1 0 0 1])
(local* white-color "The color white." [1 1 1 1])
(local* purple-color "The color purple." [(/ 90 255) (/ 34 255) (/ 139 255) 1])
(local* orange-color "The color orange." [1 (/ 127 255) (/ 80 255) 1])

(fn create-particle []
  "Create a particle with random properties starting at the bottom of
 the screen."
  (let [(w h) (love.graphics.getDimensions)]
    ;; h + 5 to initially hide it from screen.
    (var coordinates [(lume.round (lume.random 0 w)) (+ h 5)])
    (var velocity (lume.random 1 100))
    (var angular-frequency (* 2 math.pi (lume.random -10 10)))
    (var amplitude (lume.random 0 5))
    (var phase-shift (* 2 math.pi (lume.random)))
    (var color [(lume.random) (lume.random) (lume.random) (lume.random)])
    (lambda []
      (let [[old-x old-y] coordinates
            t (/ (game-timer) 100)
            ;; x = x + Acos(ωt + θ₀)
            new-x (lume.round
                   (+ old-x (* amplitude
                               (math.cos (+ phase-shift
                                            (* angular-frequency t))))))
            ;; y = y - vt
            new-y (lume.round (- old-y (* velocity t)))]
        (set coordinates [new-x new-y])
        [old-x old-y color]))))

(var* particles
      "The list of particles floating on the screen."
      [])

(var* menu-item-font
      "The font used for menu items."
      nil)

(var* menu-title-font
      "The font used for the title in the menu."
      nil)

(var* credits-url-font
      "The font used for the url in the credits.."
      nil)

(fn add-particle []
  "Add a random particle to PARTICLES."
  (table.insert particles (create-particle)))

(fn create-cyclic [m]
  "Create a cyclic array closure from the sequential table M. Each call
to the closure returns the next value in the cyclic array."
  (var* index "The captured index." 1)
  (var* len "The captured length." (length m))
    (lambda []
      (let [value (. m index)]
        (set index (+ 1 index))
        (if (> index len)
            (set index 1))
        value)))

(local* tetris-shapes
        "The available tetris shapes.

Hardcoded coordinates for all shapes and rotations.

The coordinates are in game coordinates (Y grows downwards).  The
coordinate units are blocks.

Each value is a closure that when called, returns the next rotation of
the coordinates."
        [ ;; S-tetromino
          [[[+0 +0] [+1 +0] [-1 +1] [+0 +1]]
           [[-1 -1] [-1 +0] [+0 +0] [+0 +1]]]
          ;; O-tetromino
          [[[+0 +0] [+0 +1] [+1 +1] [+1 +0]]]
          ;; L-tetromino
          [[[+0 +0] [+0 +1] [+0 +2] [+1 +0]]
           [[+0 +0] [+0 +1] [+1 +1] [+2 +1]]
           [[+1 +0] [+1 +1] [+1 +2] [+0 +2]]
           [[-1 +1] [+0 +1] [+1 +1] [+1 +2]]]
          ;; I-tetromino
          [[[+0 +0] [+0 +1] [+0 +2] [+0 +3]]
           [[-1 +1] [+0 +1] [+1 +1] [+2 +1]]]
          ;; T-tetromino
          [[[+0 +0] [+1 +0] [+2 +0] [+1 +1]]
           [[+1 -1] [+1 +0] [+2 +0] [+1 +1]]
           [[+1 -1] [+1 +0] [+2 +0] [+0 +0]]
           [[+1 -1] [+1 +0] [+1 +1] [+0 +0]]]
          ;; Z-tetromino
          [[[+0 +0] [+1 +0] [+1 +1] [+2 +1]]
           [[+1 +0] [+1 +1] [+2 +0] [+2 -1]]]
        ])

(var* shadow-block
      "The shadow block falling from above.")

(local* shadow-block-movement-delta
        "The shadow block is updated every SHADOW-BLOCK-MOVEMENT-DELTA
seconds."
        1.0)

(local* player-movement-delta
        "The player input is updated every PLAYER-MOVEMENT-DELTA
seconds."
        0.1)

(var* pile-movement-delta
      "The pile is growing every PILE-MOVEMENT-DELTA seconds. This
varies by level."
      2)

(var* last-key
      "The last key pressed by the player. When processed, it is reset to the
value nil.")

(fn get-coordinates [self]
  "Obtain the :SHAPE coordinates relative to :COORDINATES."
  (let [[x0 y0] self.coordinates]
    (lume.map self.shape
              (lambda [[x y]]
                [(+ x x0) (+ y y0)]))))

(fn new-shadow-block []
  "Create a new shadow block falling from the top."
  (let [shape-closure (create-cyclic (lume.randomchoice tetris-shapes))]
    (set shadow-block
         {:coordinates [(- (lume.round (/ width 2)) 1) (. origin 2)]
          :shape-closure shape-closure
          :shape (shape-closure)})))

(var* menu-selection
      "This is the current menu selection."
      1)

(fn menu-load []
  "Setup in the game state :menu.

This function may be called multiple times, once per transition from
:game to :menu state."
  (set particles [])
  (set menu-selection 1)
  (love.graphics.setFont menu-item-font)
  (set game-state :menu))

(fn game-load []
  "Setup in the game state :game.

This function may be called multiple times, once per transition from
:menu to :game state."
  (set pile-blocks [])
  (set score 0)
  (new-shadow-block)
  (set game-state :game))

(fn love.load []
  "One-time setup."
  (math.randomseed (os.time))
  (love.keyboard.setKeyRepeat true)
  (set credits-url-font (love.graphics.newFont "Numbeato-Italic.otf" 14))
  (set menu-item-font (love.graphics.newFont "Numbeato-Italic.otf" 24))
  (set menu-title-font (love.graphics.newFont "Numbeato-Italic.otf" 60))
  (set music (love.audio.newSource "Farting Around.mp3" "static"))
  (love.audio.play music)
  (menu-load))

(var* selected-option
      "This is set to the selected option that the player has made in
the menu. Once processed, it it set back to nil."
      nil)

(local* menu-options
        "These are the options in the menu."
        [[:start "Start game"]
         [:credits "Credits"]
         [:exit "Exit"]])

(fn update-menu-selection []
  "Update the menu selection according to LAST-KEY."
  (case last-key
    :down (if (< menu-selection (length menu-options))
              (set menu-selection (+ menu-selection 1))
              (set menu-selection 1))
    :up (if (> menu-selection 1)
            (set menu-selection (- menu-selection 1))
            (set menu-selection (length menu-options)))
    :return (set selected-option (. menu-options menu-selection))))

(fn process-selected-option []
  "Process the selected option in the menu."
  (case selected-option
    [:start msg] (game-load)
    [:credits msg] (set game-state :credits)
    [:exit msg] (love.event.quit 0))
  (set selected-option nil))

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
  (lume.any (get-coordinates shadow-block)
            (lambda [[x y]] (= x (. origin 1)))))

(fn right-wall-collision? []
  "Returns true if the SHADOW-BLOCK collides with the right wall."
  (lume.any (get-coordinates shadow-block)
            (lambda [[x y]] (= x (- width 1)))))

(fn left-wall-clip? []
  "Returns true if the SHADOW-BLOCK clips over the left wall.

This is an invalid position for the SHADOW-BLOCK to have."
  (lume.any (get-coordinates shadow-block)
            (lambda [[x y]] (< x (. origin 1)))))

(fn right-wall-clip? []
  "Returns true if the SHADOW-BLOCK clips over the right wall.

This is an invalid position for the SHADOW-BLOCK to have."
  (lume.any (get-coordinates shadow-block)
            (lambda [[x y]] (> x (- width 1)))))

(fn eq-block [b1 b2]
  "Compare two blocks coordinate-wise."
  (let [[x1 y1] b1
        [x2 y2] b2]
    (and (= x1 x2) (= y1 y2))))

(fn member-pile-blocks? [b]
  "Block is member of PILE-BLOCKS."
  (lume.any pile-blocks (lambda [b1] (eq-block b b1))))

(fn intersection []
  "Blocks shared between SHADOW-BLOCK and PILE-BLOCKS."
  (lume.filter (get-coordinates shadow-block)
               member-pile-blocks?))

(fn set-difference []
  "Blocks of SHADOW-BLOCK not in PILE-BLOCKS."
  (lume.filter (get-coordinates shadow-block)
               (lambda [b] (not (member-pile-blocks? b)))))

(fn shadow-block-pile-collision []
  "Return the number of shared blocks between shadow-block and pile."
  (length (intersection)))

(fn rotate-shadow-block []
  "Rotate the SHADOW-BLOCK once."
  (set shadow-block.shape (shadow-block:shape-closure))
  ;; Correct the positioning of the shadow block in case it is lying
  ;; outside the board.
  (while (left-wall-clip?)
    (move-block shadow-block :right))
  (while (right-wall-clip?)
    (move-block shadow-block :left)))

(fn process-last-key []
  "Process LAST-KEY, the last key pressed by the user."
  (case game-state
    :menu (do (update-menu-selection)
              (process-selected-option))
    :game (case last-key
            :down (move-block shadow-block :down)
            :left (if (not (left-wall-collision?))
                      (move-block shadow-block :left))
            :right (if (not (right-wall-collision?))
                       (move-block shadow-block :right))
            :space (rotate-shadow-block)))
  (set last-key nil))

(fn reset-timer [timer]
  "Reset a timer closure."
  (timer 0))

(fn add-pile-row []
  "Add a row to the pile."
  ;; move the pile up by 1 unit
  (set pile-blocks
       (lume.map pile-blocks (lambda [[x y]] [x (- y 1)])))
  ;; add new row
  (for [i 0 (- width 1)]
    (if (lume.randomchoice [true false])
        (table.insert pile-blocks [i (- height 1)]))))

(fn shadow-meld []
  "Meld the SHADOW-BLOCK in the PILE-BLOCKS.

Makes a new shadow block after melding."
  (do (let [xs (intersection)
            ys (set-difference)]
        (if (= 0 (length xs))
            ;; we have reached the bottom
            (set score (+ score 20))
            ;; else score the common blocks
            (set score (+ score (length xs))))
        (set pile-blocks
             (lume.filter pile-blocks
                          (lambda [b]
                            (not (lume.any
                                  xs
                                  (lambda [b1] (eq-block b b1)))))))
        (each [_ [x y] (ipairs ys)] (table.insert pile-blocks [x y]))))
  (new-shadow-block))

(fn pile-reached-top []
  "The pile has reached the top and the game is over."
  (lume.any pile-blocks
            (lambda [[x y]] (= y 0))))

(fn game-finish []
  "Finish the game."
  (menu-load))

(fn draw-title []
  "Draw the 'Shadow Tetris' title at the top."
  (let [old-font (love.graphics.getFont)
        (r g b a) (love.graphics.getColor)]
    (love.graphics.setFont menu-title-font)
    (love.graphics.setColor purple-color)
    (love.graphics.print "Shadow Tetris" 40 50)
    (love.graphics.setFont old-font)
    (love.graphics.setColor [r g b a])))

(local* credits-text
        "This is the text of the credits."
        ["Coded by nchatz314."
         "Font is 'Numbeato Font'"
         "  by 'denny-0980'."
         "You can find it here:"
         "https://www.1001fonts.com/numbeato-font.html"
         "Special thanks to"
         "#fennel for the help!"
         "Music by Kevin MacLeod."
         "https://incompetech.com/"])

(fn credits-draw []
  "Draw the credits."
  (let [(w h) (love.graphics.getDimensions)]
    (love.graphics.setColor purple-color)
    (love.graphics.rectangle "fill" 64 128 (- w 128) (- h 256))
    (love.graphics.setColor orange-color)
    (each [i msg (ipairs credits-text)]
      (if (= i 5) (love.graphics.setFont credits-url-font))
      (love.graphics.print msg 80 (+ 96 (* i 40)))
      (if (= i 5) (love.graphics.setFont menu-item-font)))))

(fn block->px [n]
  "Converts N block units to number of pixels."
  (* px n))

(fn draw-last-score []
  "Draw the last games' score."
  (let [(w h) (love.graphics.getDimensions)]
    (if score
        (love.graphics.print (string.format "Score: %d" score)
                             (+ (block->px width) 20) (- h 50)))))

(fn menu-draw []
  "Callback when drawing in the :menu or :credits state."
  (draw-title)
  (draw-last-score)
  (each [i particle-closure (ipairs particles)]
    (let [[x y color] (particle-closure)]
      (if (< y 0)
          (table.remove particles i)
          (do (love.graphics.setColor color)
              (love.graphics.circle "fill" x y 3)))))
  (each [i option (ipairs menu-options)]
    (if (= i menu-selection)
        (love.graphics.setColor red-color)
        (love.graphics.setColor white-color))
    (love.graphics.print (. option 2) 180 (+ 300 (* i 30))))
  (love.graphics.setColor white-color)
  (if (= game-state :credits)
      (credits-draw)))

(fn shadow-block-reached-bottom? []
  "Returns true if the shadow block has reached bottom."
  (lume.any (get-coordinates shadow-block)
            (lambda [[x y]] (>= y (- height 1)))))

(fn game-update []
  "Callback for updating frame before drawing in :game state."
  (if (< player-movement-delta (player-timer))
      (do (process-last-key)
          (reset-timer player-timer)))
  (if (< shadow-block-movement-delta (shadow-block-timer))
      (do (move-block shadow-block :down)
          (reset-timer shadow-block-timer)))
  (if (< pile-movement-delta (pile-timer))
      (do (add-pile-row)
          (reset-timer pile-timer)))
  (if (or (< 0 (shadow-block-pile-collision))
          (shadow-block-reached-bottom?))
      (shadow-meld))
  (if (pile-reached-top)
      (game-finish)))

(fn menu-update []
  "This is the update function for the :menu and :credits game states."
  (if (< particle-spawn-time (particle-timer))
      (do (add-particle)
          (particle-timer 0)))
  (process-last-key))

(fn love.update []
  "Callback for updating frame before drawing."
  (if (< 60 (music-timer))
      (love.audio.rewind music)
      (love.audio.play music)
      (music-timer 0))
  (case game-state
    :menu (menu-update)
    :game (game-update)))

(fn game-draw []
  "Callback when drawing in :game state."
  ;; draw a separating barrier
  (love.graphics.line (+ 1 (block->px width)) 0
                      (+ 1 (block->px width)) (block->px height))
  ;; draw the shadow-block
  (love.graphics.setColor purple-color)
  (lume.map (get-coordinates shadow-block)
            (lambda [[x y]] (love.graphics.rectangle "fill" (block->px x)
                                                     (block->px y) px px)))
  ;; draw the pile
  (love.graphics.setColor white-color)
  (lume.map pile-blocks
            (lambda [[x y]] (love.graphics.rectangle "fill" (block->px x)
                                                     (block->px y) px px)))
  ;; draw the score
  (love.graphics.print (string.format "Score: %d" score)
                       (+ (block->px width) 20) 50))

(fn love.draw []
  "Callback when drawing."
  (case game-state
    :credits (menu-draw)
    :menu (menu-draw)
    :game (game-draw)))

(fn handle-quit []
  "Handles player intention of quitting. In :game and :credits, shows
menu. In :menu, exits."
  (case game-state
    ;; we want a fresh menu, so redraw particles
    :game (menu-load)
    ;; we do not re-draw menu particles
    :credits (do (set last-key nil) (set game-state :menu))
    :menu (love.event.quit 0)))

(fn kbd [keys]
  "A closure that evaluates to false if its argument is not included
in KEYS."
  (lambda [k]
    (lume.find keys k)))

(var* keybindings
      "The keybindings for the video game.

The entries of this table are of the form

    (kbd KEYS) FUNC

where KEYS is a sequential table of keys and FUNC is the action to be
taken if the pressed key is one of KEYS. FUNC should accept an
argument which is the pressed key."
      {(kbd [:q :escape]) (lambda [k] (handle-quit))
       (kbd [:return :up :down :left :right
             :space :w :a :s :d]) (lambda [k] (set last-key k))
       })

(fn love.keypressed [k]
  "Callback when key is pressed. Looks up the key in KEYBINDINGS."
  (each [keys action (pairs keybindings)]
    (if (keys k) (action k))))

(fn love.quit []
  "Callback when game is quitting."
  ;; audio won't stop by itself on browser with love.js
  (love.audio.stop music)
  ;; false quits the game
  false)
