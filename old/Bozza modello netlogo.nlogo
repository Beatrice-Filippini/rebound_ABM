;problems to be solved/adressed: look for CHECK or FIX

extensions [csv matrix]
breed [users user]
breed [companies company]
breed [products product]

; Define product attributes
products-own [
  ;settate con csv
  p-ID
  p-name
  p-price
  p-sustainability
  p-quality
  p-acceptance
  p-shelf-life
  p-residual-life
  p-production-cost
  owner-ID
  p-amount
  p-price-min
  p-price-max
  p-sustainability-min
  p-sustainability-max
  p-quality-min
  p-quality-max
  p-acceptance-min
  p-acceptance-max
  p-shelf-life-min
  p-shelf-life-max
  p-residual-life-min
  p-residual-life-max

  ;used for utility calculations
  p-price-norm
  p-sustainability-norm
  p-quality-norm
  p-acceptance-norm
  p-residual-life-norm
  p-utility

 ]

users-own
[
  beta         ;linked to sustainability
  gamma        ;linked to price
  alpha        ;linked to quality
  delta        ;linked to acceptance
  omega        ;linked to RL/SL

  stock
  trigger      ;used to evaluate whether to buy
  stock-threshold
  c            ;stock consumption rate

  ;best-company
  utility-of-best-product
  buy-bool
]

companies-own [
  ;production-capability ;v0.4-> for now it is not a constrain
  c-ID
  company-demand     ;is used to calculate the company's earnings
  earnings
]

globals [
  max-init-stock
  threshold-1    ;will be used for the reduction of price
  threshold-2    ;will be used for the reprocessing procedure
  m1             ;matrix
  users-list
  best-products-list    ;global list which saves the p-ID of the best product chosen by each user
  best-companies-list   ;global list which saves the c-ID of the company which produces the best product
  p-net-revenues-list
  n-products

  ;used in the hatch function
  p-amount-hvr
  p-amount-svr
  p-amount-lvr
  p-amount-w
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SETUP;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;List of  all the procedures that must be included in the setup process: they will be bettere defined below
to setup
  clear-all
  file-close-all
  create-world
  init-globals
  import-data-FB
  read-file-matrix
  create-agents
  reset-ticks
end

to create-world
  ask patches [ set pcolor white ]
end

to init-globals ; NOTE: only here in the code i can have numbers because i'm setting the global variables
  set max-init-stock 50
    ; if residual life <= threshold (1-2) * shelf-life
  set threshold-1 (2 / 3)  ;here i can set it differently for the food vs fashion sector
  set threshold-2 (1 / 3)
  set m1 []
  set users-list []
  set best-products-list []
  set best-companies-list []
  set p-net-revenues-list []

  set p-amount-hvr 0
  set p-amount-svr 0
  set p-amount-lvr 0
  set p-amount-w 0
end

;import data+ create the agent "product"
to import-data-FB
    file-close-all
    file-open "Input_data_products.csv"
    let result csv:from-row file-read-line
    let m2 csv:from-file "Input_data_products.csv"
    set n-products ( length m2 - 1 )


    while [ not file-at-end? ] [
       let row csv:from-row file-read-line

       create-products 1 [
         set xcor random-xcor
         set ycor random-ycor
         set shape "box"
         set color orange
         set p-ID item 0 row
         set p-name item 1 row
         set p-price item 2 row
         set p-sustainability item 3 row
         set p-quality item 4 row
         set p-acceptance item 5 row
         set p-shelf-life item 6 row
         set p-residual-life item 7 row
         set p-production-cost item 8 row
         set owner-ID item 9 row
         set p-amount item 10 row
         set p-price-min item 11 row
         set p-price-max item 12 row
         set p-sustainability-min item 13 row
         set p-sustainability-max item 14 row
         set p-quality-min item 15 row
         set p-quality-max item 16 row
         set p-acceptance-min item 17 row
         set p-acceptance-max item 18 row
         set p-shelf-life-min item 19 row
         set p-shelf-life-max item 20 row
         set p-residual-life-min item 21 row
         set p-residual-life-max item 22 row
         set p-utility 0
      ]
    ]
    file-close
end

to read-file-matrix
    file-close-all
    file-open "matrice prodotti.csv"
    set m1 []
    let i 0
    while [ not file-at-end? ] [
       let row csv:from-row file-read-line
       set row  row
       if i > 0 [ set m1 lput row m1]
       set i i + 1
    ]
    file-close
  ;print m1
end


to create-agents

create-users n-users
  [
    set xcor random-xcor
    set ycor random-ycor
    set shape "person"
    set color blue
    set utility-of-best-product 0
    ;set best-company 0
    set beta random-float 1  ;sustainability
    set gamma random-float 1 ;price
    set alpha random-float 1 ;quality
    set delta 1 ;FIX acceptance
    set omega random-float 1 ;RL/SL
    set stock random-float max-init-stock
    set buy-bool False ; at the beginning they does not buy
    set trigger (85 + random 31)          ;FIX
    set stock-threshold 20
    set c 0.1 ; consumption rate of stock: CHECK for literature - for fashion ok around 2% vs for food a bit higher
  ]

create-companies n-companies
  [
    setxy random-xcor random-ycor
    set color black
    set size 3
    set shape "factory"
    set company-demand 0
    set earnings 0
    set c-ID 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;HOW SIMULATION WILL EVOLVE;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; How simulation will evolve
to go
  user-stock-consumption
  residual-life-consumption
  utility-function-management
  reprocess
  tick
end

to user-stock-consumption
  ask users
  [
    set stock stock * (1 - c)
  ]
end

to residual-life-consumption
  ask products
  [
    set p-residual-life (p-residual-life - 1)
    ;print (word "prod name: " p-name " prod RL: " p-residual-life " prod SL: " p-shelf-life)
  ]
end

to-report safe-divide [numerator denominator]
  if denominator = 0
  [
    report 0
  ]
  report numerator / denominator
end

to utility-function-management
  ;compute for each company the normalized score for price and sustainabilty
  ask products
  [
    ifelse (n-products = 1)
    [
      set p-sustainability-norm p-sustainability
      set p-price-norm p-price
      set p-quality-norm p-quality
      set p-acceptance-norm p-acceptance
    ]
    ;else
    [
      ; compute the maximum and minumum of price and sustainability for products
      let max-sustainability max [ p-sustainability ] of products
      let min-sustainability min [ p-sustainability ] of products
      let max-price max [ p-price ] of products
      let min-price min [ p-price ] of products
      let max-quality max [ p-quality ] of products
      let min-quality min [ p-quality ] of products
      let max-acceptance max [ p-acceptance ] of products
      let min-acceptance min [ p-acceptance ] of products

;      set p-sustainability-norm safe-divide (p-sustainability - min-sustainability) (max-sustainability - min-sustainability)
;      set p-price-norm safe-divide (p-price - min-price) (max-price - min-price)
;      set p-quality-norm safe-divide (p-quality - min-quality) (max-quality - min-quality)
;      set p-acceptance-norm safe-divide (p-acceptance - min-acceptance) (max-acceptance - min-acceptance)

      set p-sustainability-norm (p-sustainability - min-sustainability) / (max-sustainability - min-sustainability)
      set p-price-norm (p-price - min-price) / (max-price - min-price)
      set p-quality-norm safe-divide (p-quality - min-quality) (max-quality - min-quality)
      ;FIX
      set p-acceptance-norm 1
    ]
  ]

; find the best company according to each user preference
ask users
  [
    let my-beta beta ; sust-weight
    let my-gamma gamma ;price-weight
    let my-alpha alpha ; quality-weight
    let my-delta delta ; acceptance-weight
    let my-omega omega ; residual life-weight

    let utilities-list []
    let p-IDs-list []


    ask products
    [
      set p-utility ( (p-quality-norm * my-alpha) + (p-sustainability-norm * my-beta) - (p-price-norm * my-gamma)) * (p-acceptance-norm * my-delta) * ((p-residual-life * my-omega) / p-shelf-life)

      set utilities-list lput p-utility utilities-list
      set p-IDs-list lput p-ID p-IDs-list
      ;print (word "Prodotto ID: " p-ID " Utilità: " p-utility)
    ]

    let max-utility max utilities-list
    let index-score position max-utility utilities-list
    let my-best-product item index-score p-IDs-list   ;returns a p-ID
    set utility-of-best-product max-utility

    let best-company ([owner-ID] of one-of products with [p-ID = my-best-product])
    set users-list lput who users-list
    set best-products-list lput my-best-product best-products-list
    set best-companies-list lput best-company best-companies-list

    print (word "my BP: " my-best-product word "users-list: " users-list word " best-products-list: " best-products-list word " best-companies-list: " best-companies-list word " best-company: " best-company)
    ask products
    [
      set p-net-revenues-list lput ( ( [p-price] of one-of products with [p-ID = last best-products-list]) - ([p-production-cost] of one-of products with [p-ID = last best-products-list])) p-net-revenues-list
    ]


   if (stock / stock-threshold) <= (utility-of-best-product * trigger)
    [
      set buy-bool True ; the user buys an item

      ask products with [p-ID = my-best-product]
      [
        set p-amount p-amount - 1
      ]

      set stock stock + 1
      let index-user position who users-list
      let index-company index-user
      ;let my-best-company item index-company best-companies-list ;FIX: in teoria linea concenttualmente corretta
      let my-best-company last best-companies-list

      ask companies with [c-ID = my-best-company]
      [
        let index-net-revenue index-user
        let p-net-revenue item index-net-revenue p-net-revenues-list
        set earnings earnings + p-net-revenue
      ]

  ;set buy-bool false
 ]
 ]
     set best-products-list []
    set best-companies-list []

end

to discount
  ask products with [ p-residual-life <= (threshold-1 * p-shelf-life)]
  [
    set p-price 0.9 * p-price
    ;CHECK when acceptance will be implemented, then it should be decreased here
  ]
end


to reprocess
  let num-rows length  m1
  let num-columns length first m1
 ;print (word "numero righe: " num-rows word " numero colonne: " num-columns)

  let i 1 ;righe
  let j 0 ;colonne
          ;NB: per chiamare l'elemento i,j devo scrivere "item j item i m1"

  while [ i < num-rows ]
  [
    let p-name-in-matrix item j item i m1

    ask products with [p-name = p-name-in-matrix and p-residual-life <= (threshold-2 * p-shelf-life)]
      [
          set j j + 1 ;j=1

          let p-waste item j item i m1

          if (p-waste > 0)
          [
          hatch 1
            [
              ;esempio waste
              set p-name "waste"
              set p-ID "w"
              set p-amount-w p-amount * p-waste
              set p-residual-life 0
              set p-price 0
              ;introdurre costo di smaltimento
              set p-sustainability 0; fix
            ]
          ;set p-amount p-amount - p-amount-w      ;CHECK dopo qualche iterazione
          ];fine if p-waste

        while [j > 1 and j < num-columns]
        [
          set j j + 1 ;j=2
          let cell-text item j item i m1
          let numeric-part read-from-string (first (word cell-text "_"))
          let text-part last (word cell-text "_")

          if (numeric-part > 0)
          [
            if (text-part = "hvr")
               [
                  let p-hvr numeric-part
                  hatch 1
                  [
                    ;Reprocess example: fruit and vegetables
                    set p-name "higher value reprocess"
                    set p-ID "hvr"
                    set p-amount-hvr p-amount * p-hvr
                    set p-residual-life (1.1 * p-residual-life)     ;fix
                    set p-price (1.1 * p-price)                     ;fix
                    set p-sustainability 1.1 * p-sustainability     ;fix
                  ]
                  ;print (word "p-amount: " p-amount " p-amount-hvr: " p-amount-hvr " p-hvr: " p-hvr)
                  ;set p-amount p-amount - p-amount-hvr
               ]

            if (text-part = "svr")
               [
                  let p-svr numeric-part
                  hatch 1
                  [
                    ;esempio pollo-> pollo congelato
                    set p-name "same value reprocess"
                    set p-ID "svr"
                    set p-amount-svr p-amount * p-svr
                    set p-residual-life (1.1 * p-residual-life)     ;fix
                    set p-sustainability (1.1 * p-sustainability)   ; fix
                  ]
                  ;set p-amount p-amount - p-amount-svr
               ]

            if (text-part = "lvr")
               [
                  let p-lvr numeric-part
                  hatch 1
                  [
                    ;esempio pasta -> pasta con semola rimacinata
                    set p-name "lower value reprocess"
                    set p-ID "lvr"
                    set p-amount-lvr p-amount * p-lvr
                    set p-residual-life (1.1 * p-residual-life)     ;fix
                    set p-price 0.9 * p-price                       ;fix
                    set p-sustainability (1.1 * p-sustainability)   ;fix
                  ]
                  ;set p-amount p-amount - p-amount-lvr
               ]
          ]; end of if (numeric-part>0)
      ]; end of second while

        set p-amount ( p-amount - p-amount-w - p-amount-hvr - p-amount-svr - p-amount-lvr)

    ]; end of ask product
    set p-amount-w 0
    set p-amount-hvr 0
    set p-amount-svr 0
    set p-amount-lvr 0
    set i i + 1
    set j 0
  ]

end
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
1.0
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
100
10.0
5
1
agents
HORIZONTAL

MONITOR
1005
24
1103
85
Mean price
precision mean ( [p-price] of products ) 2
17
1
15

MONITOR
1005
111
1163
172
Mean sustainability
precision mean [ p-sustainability ] of products  2
17
1
15

MONITOR
1007
193
1181
254
Mean Stock of Products
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
Stock of products
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
16
188
191
249
n-products
n-products
0
1
15

MONITOR
1015
275
1086
320
Max stock
max [stock] of users
17
1
11

@#$#@#$#@
## COSA SISTEMARE?

### FUTURE IMPLEMENTATION

- inserire dati companies da csv
- controllare che le variabili importate da csv vengano assegnate correttamente ai prodotti


### Problemi da risolvere

4. far generare alla compagnia dei prodotti nuovi con attributi che rientrino nei limiti settati
5. extra modello (da fare per la tesi): disegnare grafo sulla base della matrice aggiornata


n. in setup procedure - init- globals abbiamo inserito ask turtles altrimenti dava errore: ha senso?


### problemi risolti
1. Aggiungere in file csv le variabili min e max (prezzo, sustainability, quality...etc)
2. Aggiungere delle categorie di prodotti
3. sistemare matrice con le percentuali giuste (da fare dopo aver aggiunto i prodotti)
- capire come gestire il profitto: entrano in gioco variabili user-owned, product-owned e company-owned 


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
