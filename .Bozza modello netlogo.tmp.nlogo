;problems to be solved/adressed: look for CHECK or FIX

extensions [matrix]
breed [users user]
breed [companies company]
breed [products product]

; Define users attributes
users-own [
  users-demand
  utility
  sustainability-i
  price-i
  beta
  gamma
  alpha
  delta
  omega
  stock
  stock-input
  trigger

  ;temporary variables
  best-company ;it is the i of max_i
  buy-bool
  total-consumption
]

; Define companies attributes
companies-own [
  ;production-capability ;v0.4-> for now it is not a constrain
  company-demand

  profit
  product-revenue
  target-demand
  target-price

  ; temporary variables
  temp-score ; a temporary value  to be used to make the decision for each user


  ;v0.4-> variable added in this version
  bool-decrease-price
  bool-increase-price
  bool-increase-sust
  bool-decrease-sust
  counter-decrease-price
  counter-increase-price
  counter-increase-sust
  counter-decrease-sust
]

; Define product attributes
products-own [
  p-price
  p-sustainability
  p-quality
  p-acceptance

  p-cost

  p-price-norm
  p-sustainability-norm
  p-quality-norm
  p-acceptance-norm
  p-residual-life-norm


  p-shelf-life
  p-residual-life

  p-amount

]

; Define global variables
globals [
  n ;number of companies
  n-products
  max-price-possibile
  max-budget
  target-demand-max
  product-demand-history
  c ;clothes consumption rate
  stock-threshold
  init-stock
  mean-trigger
 ;v0.4
  price-period
  sust-period
 ;v0.5
  threshold-1
  threshold-2
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;List of  all the procedures that must be included in the setup process: they will be bettere defined below
to setup
  clear-all
  create-world
  create-agents
  init-globals
  reset-ticks
end

to init-globals ; NOTE: only here in the code i can have numbers because i'm setting the global variables
  set n 10
  set max-price-possibile 100
  set max-budget 500
  set target-demand-max 30

  set product-demand-history []
  set c 0.02 ; consumption rate of stock: CHECK for literature
  set stock-threshold 20
  set init-stock 10
  set mean-trigger 1
  set product-demand-history[]
  set price-period 4 ;hp: i do not need a long period of time with sales<target in order to change the price (f.e. 4 weeks)
  set sust-period 12 ;hp: before implementing changes in the sustainability practices, i need to observe low sales for a longer period of time (f.e. 3 months)


end

to create-world
  ask patches [ set pcolor white ]
end

to create-agents
create-users n-users[
    set xcor random-xcor
    set ycor random-ycor
    set shape "person"
    set color blue
    set stock random-float init-stock
    set stock-input 0
    set buy-bool False ; at the beginning they does not buy
    set total-consumption 0 ;v0.4

    set trigger mean-trigger
    set beta random-float 1
    set gamma random-float 1
    set alpha random-float 1
    set delta random-float 1
    set omega random-float 1

     ]

create-products n-products [
    set xcor random-xcor
    set ycor random-ycor
    set shape "box"
    set color red
      set p-sustainability random-float 1
      set p-price random 10 ;FIX
      set target-price p-price
      set p-cost 1 ;for now, the production cost is the same for each company

    ;v0.5
  set threshold-1 (1 / 3) * p-shelf-life  ;here i can set it differently for the food vs fashion sector
  set threshold-2 (2 / 3) * p-shelf-life

  set p-residual-life random 10   ;fix ASK PROF (maybe from excel file?)

  set p-amount random 10   ;fix
  ]

  create-companies n-companies [
    setxy random-xcor random-ycor
    set color black
    set size 3
    set shape "factory"
    ;let product-revenue p-price

    ;set production-capability random 100
    set profit product-revenue * company-demand
    set target-demand random target-demand-max


    ;v0.4
    set bool-decrease-price False
    set bool-increase-price False
    set bool-increase-sust False
    set bool-decrease-sust False
    set counter-decrease-price 0
    set counter-increase-price 0
    set counter-increase-sust 0
    set counter-decrease-sust 0

  ]



  ; Initialize company price
  ; Initialize company attributes, production capabilities etc...
end

;to update-product-demand-history
;  let current-demand company-demand
;  set product-demand-history lput company-demand product-demand-history
;end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;HOW SIMULATION WILL EVOLVE;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; How simulation will evolve
to go
  ;utility-function-creation
  user-stock-consumption
  utility-function-management
  user-stock-allocation
  ;users-demand-allocation
  price-demand-regulation
  sustainability-demand-regulation
  discount
  tick
end

to user-stock-consumption

  ask users [
    set stock stock * (1 - c) + stock-input
  ]

end

to utility-function-management

  ; compute the maximum and minumum of price and sustainability for products
  let max-sustainability max [ p-sustainability ] of products
  let min-sustainability min [ p-sustainability ] of products
  let max-price max [ p-price ] of products
  let min-price min [ p-price ] of products
  let max-quality max [ p-quality ] of products
  let min-quality min [ p-quality ] of products
  let max-acceptance max [ p-acceptance ] of products
  let min-acceptance min [ p-acceptance ] of products
  let max-residual-life max [ p-residual-life ] of products
  let min-residual-life min [ p-residual-life ] of products

  ; compute for each company the normalized score for price and sustainabilty
  ask companies [
    set p-sustainability-norm (p-sustainability - min-sustainability) / (max-sustainability - min-sustainability)
    set p-price-norm (p-price - min-price) / (max-price - min-price)
    set p-quality-norm (p-quality - min-quality) / (max-quality - min-quality)
    set p-acceptance-norm (p-acceptance - min-acceptance) / (max-acceptance - min-acceptance)
    set p-residual-life-norm (p-residual-life - min-residual-life) / (max-residual-life - min-residual-life)


  ]

  ; find the best company according to each user preference
  ask users [

    let my-beta beta ; sust-weight
    let my-gamma gamma ;price-weight
    let my-alpha alpha ; quality-weight
    let my-delta delta ; acceptance-weight
    let my-omega omega ; residual life-weight

    set best-company max-one-of companies [p-quality-norm * my-alpha + p-sustainability-norm * my-beta - p-price-norm * my-gamma - p-acceptance-norm * my-delta + p-residual-life-norm * my-omega]
    set utility ([p-quality-norm] of best-company * my-alpha)
                 + ([ p-sustainability-norm ] of best-company * my-beta)
                 - ([ p-price-norm ] of best-company * my-gamma)
                 - ([p-acceptance-norm] of best-company * my-delta)
                 + ([p-residual-life-norm] of best-company * my-omega)

  ]



  ;set utility-function (beta * sustainability-i ^ n) - (trigger * price-i ^ n)

    ;set target-price random max-target-price  ;here i assign each user a target-price as a random variable
     ; future application: assign the target price using real data/a normality function with mean= avg budget per person when shopping for textile products
    ;set budget-flexibility random-float 1

end

to user-stock-allocation

  ask users [

    ; decide if to buy
;    print "******"
;    print who
;    print stock / stock-threshold
;    print utility * trigger
;    print utility
    ifelse stock / stock-threshold <= utility * trigger [
      set buy-bool True ; the user buys an item
      set stock stock + 1
      set total-consumption count users with [ buy-bool]  ; Calculate total consumption

    ]
    [
      set buy-bool False
    ]

    ask companies [
      let n-buyers count users with [ best-company = myself and buy-bool ]
      set company-demand n-buyers
      set profit company-demand * (p-price - p-cost)
    ]
  ]


;  ask companies [
;  ]
;  ask users [
;    set stock stock * (1 - c) + stock-input ;usury
;    let ratio stock / stock-treshold ; decision-making ratio
;    ifelse ratio < max utility * trigger [
;      set stock-input 1 ;
;    ]
;    [
;      set stock-input 0
;    ]
;    set stock stock * (1 - c) + stock-input
;  ]
end


to users-demand-allocation
  ;ask companies [ set company-demand 0 ]
  let companies-demand sum stock-input

end

    ; here i create a list: i initialize it as empty and at each tick, a value is added to the list
    ; then, in order to understand how/when to act with a pricing strategy, i create a sublist which only takes in consideration the latest n elements of the list (depending on the period considered)
to price-demand-regulation
  ask companies[
    set product-demand-history lput company-demand product-demand-history
    if ticks >= price-period [
        let last-price-period sublist product-demand-history (length product-demand-history - price-period) (length product-demand-history)
        ; sublist starting from position lenght-3 (inclusive) and lenght (CHECK: guide  says right extremity is exclusive)


      ;constrain on the price: cannot decrease until reaching zero
      ifelse (p-price  >= target-price * 0.5) [
        ;;; if demand < target for 4 periods--> decrease price of 10%
        if (company-demand < target-demand) and (mean last-price-period < target-demand) [
          set p-price p-price * 0.9
          set bool-decrease-price True
        set counter-decrease-price counter-decrease-price + 1
        set bool-decrease-price False
        ]
                          ;;; if demand > target for 4 periods--> increase price of 10%
        if (company-demand > target-demand) and (mean last-price-period > target-demand)[
          set p-price p-price * 1.1
          set bool-increase-price True
        set counter-increase-price counter-increase-price + 1
        set bool-increase-price False
        ]


      ]

      [
      ]




    ]
  ]
end

to sustainability-demand-regulation
  ask companies[
    set product-demand-history lput company-demand product-demand-history
    if ticks >= sust-period [
        let last-sust-period sublist product-demand-history (length product-demand-history - sust-period) (length product-demand-history)
        ; sublist starting from position lenght-10 (inclusive) and lenght+1 (because exclusive

                      ;;; if demand < target for 12 periods--> increase sustainability level of 1%
        if (company-demand < target-demand) and (mean last-sust-period < target-demand) [

        if(p-sustainability * 1.1 <= 1) [
          set p-sustainability p-sustainability * 1.01  ;increase sustainability of the product of 10%
          set bool-increase-sust True
          set counter-increase-sust counter-increase-sust + 1
        set bool-increase-sust False
        ]
        ]
     ;; Now i decrease sustainability
     ;; BUT theoretically, no company should be interested in decreasing sustainability
;      if (company-demand > target-demand) and (mean last-sust-period > target-demand)[
;          set p-sustainability p-sustainability * 0.9
;          set bool-decrease-sust True
;        set counter-decrease-sust counter-decrease-sust + 1
;        set bool-decrease-sust False
;        ]
        ]

    ]
end


to discount
  ask products [
    set p-residual-life p-residual-life - 1
  ]

  ask companies [
    ask products [
      if (p-residual-life = threshold-1) [
        set p-price p-price * 0.9  ;FIX
        set p-quality p-quality * 0.9  ;FIX
      ]
    ]
  ]
end



to reprocess
  ask companies [

    if (p-residual-life = threshold-2)[


    ]
  ]

end





if [type ] of merce == "merce 1" [
   if [ residual-life ] of merce < threshold-res-lif-1 [
; sapendo che la percentuale di 1 che diventa 2 dopo la vita residua è pct-1-2 e quelal che diventa rifiuto è pct-1-waste
let amount-good amount
hatch-merce 1 [
set type "merce 2"
set p-amount p-amount * pct-1-2
    ]
hatch-merce 1 [
set type "waste"
set p-amount p-amount * pct-1-waste
    ]
  ]
]
@#$#@#$#@
GRAPHICS-WINDOW
289
10
625
347
-1
-1
9.94
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
49
292
112
325
setup
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
116
292
179
325
go
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

SLIDER
18
116
190
149
n-companies
n-companies
1
20
7.0
1
1
agents
HORIZONTAL

SLIDER
17
151
191
184
n-users
n-users
10
500
500.0
10
1
agents
HORIZONTAL

MONITOR
1005
76
1103
137
Mean price
precision mean ( [product-price] of companies ) 2
17
1
15

MONITOR
1003
162
1161
223
Mean sustainability
precision mean [ product-sustainability ] of companies  2
17
1
15

MONITOR
1005
244
1189
305
Mean Stock of Clothes
precision mean [ stock ] of users 2
17
1
15

BUTTON
182
292
265
325
Go (once)
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
665
14
975
177
Buyers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count users with [ buy-bool ]"

PLOT
665
196
978
350
Stock of clothes
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [ stock ] of users"

MONITOR
1023
370
1236
431
Avg product Sustainability
precision mean [product-sustainability] of companies 4
17
1
15

PLOT
59
374
334
586
Relationship price-sustainability
product-sustainability
product-price
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"default" 1.0 0 -16777216 false "" "plotxy mean [product-sustainability] of companies   mean [ product-price ] of companies "

PLOT
588
368
1011
603
Relationship sustainability-consumption
product-sustainability
n-products-bought
0.5
1.0
0.0
10.0
true
true
"" ""
PENS
"default" 1.0 2 -2674135 false "" "plotxy mean [product-sustainability] of companies count users with [ buy-bool ]"

SLIDER
18
187
190
220
n-products
n-products
1
20
11.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## COSA DEVI SISTEMARE?


### Problemi da risolvere
1. in questo modo la sostenibilità viene aumentata e arriva subito a 1






### 12/04/2024

1. sistema il fatto che al crescere del prezzo il temp-score diminuisca
2. inserisci una variabile profitto  dentro le aziende
3. fare che la domanda e la sostenibilità in qualche modo siano cambiate dalle aziende per  ottimizzare il profitto (es: se sono sotto la media delle vendite, cambio a caso uno delle due)

Importante da ricordare: se l'obiettivo è studiare l'effetto rebound, a un certo punto bisognerà inserire che la domanda dei gruppi cambia con la sostenibilità e aumenta, e anche inserire dentro il consumo di CO2 o simili in modo esplicito


## CHE COSA HO FATTO

1. ho implementato un sistema tale per cui viene dato assegnato uno score a prezzo e sostenibilità che poi vengono moltiplicati per il peso che  ogni gruppo da a prezzo e sostenibilità
2. inserisci una variabile profitto  dentro le aziende
3. fare che la domanda e la sostenibilità in qualche modo siano cambiate dalle aziende per  ottimizzare il profitto (es: se sono sotto la media delle vendite, cambio il prezzo)


## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

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
NetLogo 6.4.0
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
