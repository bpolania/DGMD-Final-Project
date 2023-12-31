globals [
  number-of-robots   ;; Total number of robots
  goal               ;; Destination patch for robots
  goal-found         ;; Whether the goal is found
  learning-rate      ;; Q-learning parameter: alpha
  exploration-rate   ;; Probability of exploring versus exploiting
  discount-rate      ;; Q-learning parameter: gamma (future reward discount factor)
  q-table            ;; Q-value storage for states and actions
  times              ;; Time taken by the robots to find the goal
  random-times exploit-times random-unexplored exploit-unexplored  ;; Different types of exploration-exploitation metrics
  exploit            ;; Flag to check if current run is a test (exploitation) or training
  filename           ;; File name for logging output data
]

turtles-own [
  start-state action end-state      ;; Variables to store states and actions for Q-learning
  dist-to-goal                      ;; Current distance to goal for reward calculation
  turned-towards-obstacle           ;; Flag for checking if robot faced an obstacle
  turned-towards-black              ;; Flag for direction toward most unexplored territory
  moved-onto-black                  ;; Flag for checking if robot moved onto an unexplored patch
  black-square-count                ;; Count of unexplored patches around the robot
  toward-black-x toward-black-y     ;; Coordinates for the most unexplored direction
]

;; Resets the model and sets up the robots.
to setup
  clear-all
  ;; Initializing variables.
  set number-of-robots 5
  set learning-rate 1
  set exploration-rate 1
  set discount-rate 0.5  ;; Concern ratio for long-term versus short-term rewards.
  ;; Initializing lists.
  set times (list)
  set random-times (list)
  set exploit-times (list)
  set random-unexplored (list)
  set exploit-unexplored (list)
  set goal patch 0 0  ;; Initializing goal with a dummy value.
  set filename "test"
  set exploit false
  ;; Initializing q-table with zeros.
  set q-table n-values 324 [n-values 4 [0]]
  start-round
end

;; Starts a round in the simulation.
to start-round
  ;; Resets without clearing globals or plots.
  clear-ticks
  clear-turtles
  clear-patches
  clear-drawing
  set goal-found 0

  ;; Initializing turtles (robots).
  create-turtles number-of-robots [
    set start-state (n-values 4 [black])
    set toward-black-x 10
    set toward-black-y 10
    set heading 0
  ]
  create-obstacles
  create-goal  ;; Continuously attempts to create a goal until successful.

  ;; Sets each turtle's distance to the goal.
  ask turtles [set dist-to-goal distance goal]

  ;; Uses DFS to check if a path to the goal exists.
  let obstacles-exist dfs  ;; dfs returns 0 (failure) or 1 (success).
  while [obstacles-exist = 0] [
    create-obstacles
    create-goal
    set obstacles-exist dfs
    show obstacles-exist
  ]
  reset-ticks
end

;; Placeholder procedure for the main simulation loop.
to go
  check-completion  ;; Checks if the round has finished.

  ;; Updates turtles based on their environment and decisions.
  ask turtles [
    set start-state sense-state
    set black-square-count exploration-value
    choose-action
    move
    mark-as-explored
    set end-state sense-state
    update-table
  ]
  tick
end

;; Records certain metrics when exploiting the environment.
to record
  if exploit [
    set exploit-times lput ticks exploit-times
    set exploit-unexplored lput count patches with [pcolor = black] exploit-unexplored
  ]
end

;; Resets only the robots without changing the map.
to reset-robots
  clear-ticks
  clear-turtles
  clear-exploration
  set goal-found 0
  ;; Recreating turtles (robots).
  create-turtles number-of-robots [
    set start-state (n-values 4 [black])
    set toward-black-x 10
    set toward-black-y 10
    set heading 0
  ]
  ask turtles [set dist-to-goal distance goal]
  reset-ticks
end

;; Clears exploration markers on the map.
to clear-exploration
  ask patches [
    if pcolor = green + 0.25 [ set pcolor black ]
  ]
end

;; Generates obstacles on the map.
to create-obstacles
  clear-obstacles
  repeat 100 [  ;; Quasi-randomly places obstacles.
    let x random 32 - 16
    let y random 32 - 16
    let obstacle patch x y
    if (x < -2 or y < -2 or x > 2 or y > 2) and (obstacle != goal) [
      ask obstacle [spawn-obstacle]
    ]
  ]
end

;; Removes all obstacles from the map.
to clear-obstacles
  ask patches [
    if pcolor = brown [ set pcolor black ]
  ]
end

;; Designates a non-obstacle patch as the goal.
to create-goal
  ask goal [ set pcolor black ]
  let done 0
  while [done = 0] [
    let x random 32 - 16
    let y random 32 - 16
    let potential-goal patch x y
    if ([pcolor] of potential-goal != brown) and (potential-goal != patch 0 0) [
      ask potential-goal [set pcolor red]
      set goal potential-goal
      set done 1
    ]
  ]
end

to check-completion
  if (number-of-robots > count turtles) [
    let decrease 0.05
    if exploration-rate < 0.6 and exploration-rate > 0.3 [
      set decrease 0.01
    ]
    if exploration-rate <= 0.3 [
      set decrease 0.005
    ]
    if exploration-rate < 0.05 [
      set decrease 0
    ]

    set times lput ticks times
    set exploration-rate (exploration-rate - decrease)
    set learning-rate (learning-rate - decrease)
    show exploration-rate
    start-round
  ]
end

;;this details how a robot chooses one of the possible actions to take
to choose-action
  ;; decide whether to explore or exploit the table
  let rand random-float 1 ;; between 0 (inclusive) and 1 (exclusive)
  if rand > exploration-rate [
    set action exploit-table start-state
  ]
  if rand <= exploration-rate [
    ;; randomly explore
    set action (random 4)
  ]

  ;; either way, now we execute the appropriate turn
  (ifelse
      action = 0 [
      right 0
    ]
    action = 1 [
      right 90
    ]
    action = 2 [
      right 180
    ]
    action = 3 [
      right 270
    ])
  ifelse [pcolor] of patch-ahead 1 = brown [
      set turned-towards-obstacle 1
  ]
  [
    set turned-towards-obstacle 0
  ]
end

to-report exploit-table [state]
  ;; exploit q-table to decide which action to take
    let state-number state-to-number state
    let row item state-number q-table
    ;; find which index holds the max value in row
    let max-reward max row
    report position max-reward row
end

to-report sense-state
  ;; sense the four squares around myself: [ahead, right, behind, left]
  let sensor-output (list)
  let angle 0
  while [angle < 360] [
    let p patch-right-and-ahead angle 1
    let colour [pcolor] of p
    set sensor-output lput colour sensor-output
    set angle angle + 90
  ]
  ;; get which direction is the robot that sees the most black squares
  let shortest-distance 100
  let best-x 200
  let best-y 200
  ask other turtles [
    let dist distance myself
    if black-square-count > 0 and dist < shortest-distance [
      set shortest-distance dist
      set best-x pxcor
      set best-y pycor
    ]
  ]
  ;; figure out which direction to go in
  set angle 0
  if best-x != 200 and patch pxcor pycor != patch best-x best-y [
    set angle towards (patch best-x best-y) - heading
    set toward-black-x best-x
    set toward-black-y best-y
  ]
  let dir 0
  if (315 < angle and angle <= 359) or (0 <= angle and angle <= 45) [
    set dir 0
  ]
  if 45 < angle and angle <= 135 [
    set dir 1
  ]
  if 135 < angle and angle <= 225 [
    set dir 2
  ]
  if 225 < angle and angle <= 315 [
    set dir 3
  ]
  let state lput dir sensor-output
  report state
end

;;this will calculate a value for how unexplored the robot's immediate area is
to-report exploration-value
  let value 0
  if [pcolor] of patch-ahead 1 = black [ ;;patch directly ahead
    set value (value + 1)
  ]
  if [pcolor] of patch-right-and-ahead 90 1 = black [ ;;patch directly to right
    set value (value + 1)
  ]
  if [pcolor] of patch-right-and-ahead 45 1 = black [ ;;patch diagonal up right
    set value (value + 1)
  ]
  if [pcolor] of patch-left-and-ahead 90 1 = black [ ;;patch directly to left
    set value (value + 1)
  ]
  if [pcolor] of patch-left-and-ahead 45 1 = black [ ;;patch diagonal up left
    set value (value + 1)
  ]
  if [pcolor] of patch-right-and-ahead 135 1 = black [ ;;patch diagonal down right
    set value (value + 1)
  ]
  if [pcolor] of patch-left-and-ahead 135 1 = black [ ;;patch diagnoal down left
    set value (value + 1)
  ]
  if [pcolor] of patch-left-and-ahead 180 1 = black [ ;;patch directly behind
    set value (value + 1)
  ]
  report value
end

;;the robots can move after turning in a direction
;;they will not move forward if there is an obstacle in front of them
;;the robots will disappear if they enter the goal, or are next to the goal
to move
  set moved-onto-black false
  set turned-towards-black false
  if [pcolor] of patch-ahead 1 != brown [
    fd 1
  ]
  if pcolor = black [
    set moved-onto-black true
  ]
  if pcolor = red or near-goal [
    if goal-found = 0 [
      set goal-found 1
    ]
    die
  ]
  let patch-toward-black patch toward-black-x toward-black-y
  if patch pxcor pycor != patch-toward-black [
    if heading = (towards patch-toward-black) [
      set turned-towards-black true
    ]
  ]
end

to-report near-goal
  if [pcolor] of patch-right-and-ahead 0 1 = red [
    report true
  ]
  if [pcolor] of patch-right-and-ahead 90 1 = red [
    report true
  ]
  if [pcolor] of patch-right-and-ahead 180 1 = red [
    report true
  ]
  if [pcolor] of patch-right-and-ahead 270 1 = red [
    report true
  ]
  report false
end

;;this keeps track of the territory covered by the robots
to mark-as-explored
  set pcolor green + 0.25
end

;;this will add or subtract weight to/from the entry for the completed action in the Q-table
;;depending on its calculated reward value
to update-table

  let reward action-reward

  let start-state-number state-to-number start-state
  let row item start-state-number q-table
  let old-q-value item action row

  let end-state-number state-to-number end-state

  ;; get the max of the row that corresponds to the "next state" ie current state after taking action
  let estimated-max-future-reward (max item end-state-number q-table)

  ;; calculate new q-value
  let new-q-value (1 - learning-rate) * old-q-value + learning-rate * (reward + discount-rate * estimated-max-future-reward)

  ;; place it in the table
  let old-row item start-state-number q-table
  let new-row replace-item action old-row new-q-value
  set q-table replace-item start-state-number q-table new-row

end

;; given a state [a b c d] returns a distinct, stable number between 0 and 323 inclusive
to-report state-to-number [state-list]
  let shifted-list (list)
  let a color-to-number (item 0 state-list)
  let b color-to-number (item 1 state-list)
  let c color-to-number (item 2 state-list)
  let d color-to-number (item 3 state-list)
  let f item 4 state-list
  report a * 1 + b * 3 + c * 9 + d * 27 + f * 81
end

to-report color-to-number [x]
  if x = black [report 0]
  if x = green + 0.25 [report 1]
  if x = brown [report 2]
  report 0
end

;;this will calculate the value of an action the robot just took through the
;;Q-learning algorithm
to-report action-reward
  let total-reward 0 ;;calculated by adding rewards and subtracting penalties
  let toward-goal-reward 0 ;;whether or not the robot has moved towards the goal
  let explore-reward 0 ;;whether or not the robot is moving into new territory
  let black-square-reward 0 ;; whether the robot moved onto a black square
  let move-to-black-squares-reward 0  ;; whether the robot moved toward other black squares when it didn't see any black squares near itself
  let obstacle-penalty 0 ;;used if the robot chooses to face towards an obstacle

  if turned-towards-obstacle = 1 [
    set obstacle-penalty 100
  ]

  ;;exploration and spreading out is prioritized when the goal has not been found
;  ifelse goal-found = 0 [
    ;other methods determine the exploration and spread values
    ;set explore-reward exploration-value
    if moved-onto-black [
      set black-square-reward 10
    ]
    ;; determine whether to reward for moving toward other robot's black squares
    if black-square-count = 0 and turned-towards-black [
      set move-to-black-squares-reward 2
    ]
    ;;calculate the reward
    set total-reward (exploration-value + black-square-reward + move-to-black-squares-reward - obstacle-penalty)
;  ]

  report total-reward
end

;; Function to spawn a randomly-sized obstacle on the map.
to spawn-obstacle
  ;; Determine the random size of the obstacle.
  let obstacle-size random 6
  ;; Adjust the size for a minimum of 2 and a maximum of 7.
  set obstacle-size (obstacle-size + 2)

  ;; Randomly determine an x-coordinate difference for obstacle generation.
  let x-difference random 2
  ;; Adjust to range between -1 and 1.
  set x-difference (x-difference - 1)

  ;; Randomly determine a y-coordinate difference for obstacle generation.
  let y-difference random 2
  ;; Adjust to range between -1 and 1.
  set y-difference (y-difference - 1)

  ;; Set the current patch's color to brown, marking the beginning of the obstacle.
  set pcolor brown

  ;; Expand the obstacle based on the determined size.
  repeat obstacle-size [
    ;; Examine neighboring patches to determine the obstacle's growth.
    repeat 3 [
      repeat 3 [
        ;; Ensure the patch isn't examining itself.
        if x-difference != 0 or y-difference != 0 [
          ;; Check if surrounding patches are available for obstacle expansion.
          if [pcolor] of patch (pxcor + (x-difference * 2)) (pycor + (y-difference * 2)) != brown
          and [pcolor] of patch (pxcor + x-difference) (pycor + y-difference) != brown [
            ;; Mark available patches as part of the obstacle.
            ask patch (pxcor + x-difference) (pycor + y-difference) [set pcolor brown]
            ;; Toggle the x-coordinate direction for obstacle expansion.
            ifelse x-difference = 1
              [set x-difference -1]
              [set x-difference (x-difference + 1)]
          ]
          ;; Toggle the y-coordinate direction for obstacle expansion.
          ifelse y-difference = 1
            [set y-difference -1]
            [set y-difference (y-difference + 1)]
        ]
      ]
    ]
  ]
end


to-report dfs
  ; Begin Depth First Search. Assuming 'goal' is the starting node.
  let visited (list goal)  ; List with starting patch as visited
  let stack (list goal)    ; Stack initialized with the starting patch

  ; Continue until there are no patches left in the stack
  while [not empty? stack] [
    ; Retrieve and remove the current patch from the stack
    let current last stack
    set stack remove-item (length stack - 1) stack

    ; Terminate with success if the target patch (patch 0 0) is reached
    if current = patch 0 0 [ report 1 ]

    ; Directly fetch non-obstacle neighbors which haven't been visited yet
    ask current [
      let valid-neighbors neighbors4 with [ not member? self visited and pcolor != brown ]

      ; Add them to the visited list and stack
      ask valid-neighbors [
        if not member? self visited [
          set visited lput self visited
          set stack lput self stack
        ]
      ]
    ]
  ]

  ; If traversal concludes without reaching the target, report failure
  report 0
end
@#$#@#$#@
GRAPHICS-WINDOW
34
11
471
449
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
112
474
256
507
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
269
474
407
507
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This is a simulation of a robot swarm which explores its environment in search of a randomly generated goal. At first, the swarm explores randomly. A simple Q-learning algorithm is implemented in this model to allow the swarm to be trained to explore more effectively. 

The robots mark a square green when they move over it, and can sense whether a square is green or black. Robots can also communicate to one another whether there is unexplored space nearby. The Q-learning reward function rewards robots for moving onto unexplored spaces, for moving toward unexplored areas reported by other robots if they don't themselves see unexplored space, and for not running into obstacles.

When learning is enabled, the current learning rate is printed out in the console. It decreases during the learning process automatically to a minimum of 0.05.

## HOW TO USE IT

To reset the simulation and generate a new randomly generated environment with obstacles and a goal, use the "setup" button. 

To start the simulation, use the "go" button, which repeatedly has the robot swarm explore, calulating and storing rewards for each action a robot takes according to the Q-learning algorithm. When one of the robots finds the goal, a new environment will be generated automatically, the swarm will be reset to the center of the screen, and exploration and learning automatically continues. 

To create a file with a printout of the current Q-table and a list of the number of ticks taken to find the goal in each trial so far, use the "output" button.

To stop the robots from learning and to make all of their actions be decided according to the Q-table instead of possibly being randomly decided, turn on test-mode. This will not reset anything, just temporarily change the robot's behavior so you can more easily see what they have learned to do so far.

Similarly, you can turn off or on learning without changing or resetting anything else using the "learn" switch.

To run a test suite of 50 randomly generated environments, use the "test" button. This runs the swarm twice on each environment, once randomly and once with the learned policy, and prints the number of ticks each trial took to a file. It also prints the number of unexplored spaces at the end of each trial to a file.

Finally, use the "start-round" button to generate a new random environment and reset the robots without resetting the Q-table or anything else in the simulation.

## CREDITS AND REFERENCES

Created by Keara Berlin and Linnea Prehn for the AI Robotics capstone course at Macalester College, under the guidance of Prof. Susan Fox, Spring 2020.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
