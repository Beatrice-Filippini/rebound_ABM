;problems to be solved/adressed: look for CHECK or FIX or REVIEW

extensions [csv matrix]
breed [users user]
breed [companies company]
breed [products product]

; Define product attributes
products-own [
  ;attributes
  p-name
  p-price
  p-sustainability
  p-quality
  p-acceptance
  p-shelf-life
  p-residual-life
  p-RL/SL-ratio
  p-production-cost
  owner-ID
  p-amount
  primary-prod
  p-stock-threshold

  ;used for utility calculations
  p-price-norm
  p-sustainability-norm
  p-quality-norm
  p-acceptance-norm
  p-RL/SL-ratio-norm
  p-utility
  p-init-utility

  ;used in the strategy-discount procedure
  p-discount
  ;used in the strategy-reprocess procedure
  p-sust-increase

 ]

users-own
[
  beta                 ;linked to sustainability
  gamma                ;linked to price
  alpha                ;linked to quality
  delta                ;linked to acceptance
  omega                ;linked to RL/SL

  stock                ;this is the stock of products of each user (it is a list of (n-class-of-products) items)
  trigger              ;Review:  used to evaluate whether to buy
  budget-of-period     ;available amount of money for the purchase of products
  tot-budget

  ;best-company
  utility-of-best-product
  buy-bool             ;it is a boolean variable: if true, the user is buying. If false the user the opposite
]

companies-own [

  ;company behaviour
  ;These are similar in concept to the product attributes, but applied to the company: the company's profile is defined by these attributes, which fall on a scale from 0 to 1.
  ;For example, a company with a c-price of 0.2 would be considered a discount retailer compared to a company with a c-price of 0.8.
  c-price
  c-sustainability
  c-quality

  ;production-capability
  c-ID
  c-demand             ;List: it is used in the setup procedure to calculate the company's average demand for each class of products, starting from the sales history
  earnings

  ;companies memory
  c-memory             ;List of lists - is the sales history of the company and tracks the sales grouped by class of products for 10 periods: the first element (the first sublist) is the most recent one.
                       ;It is used to take decisions regarding how much to produce and to keep as stock.
  c-new-memory         ;List - it is a support variable used to calculate for each class, the sum of bought products. It represents the c-memory of the current tick.
                       ;It will be used to update the actual memory (c-memory) by becoming the first sublist. Therefore the last element will be removed in order to keep the main memory of length 10.

]

globals [
  threshold-1           ;will be used for the reduction of price
  threshold-2           ;will be used for the reprocessing procedure
  m1                    ;matrix used to import data regarding the reprocessing
  users-list
  best-products-list    ;global list which saves the who of the best product chosen by each user
  best-companies-list   ;global list which saves the c-ID of the company which produces the best product
  ;p-net-revenues-list   ;is a list containing elements that represents the total sum for each company of (earnings - production costs) for each product sold
  n-class-of-products
  c-len-memory          ;length of the list c-memory: it indicates the number of sublists present in c-memory. Each sublist represents a tick
  wasted-prod           ;products that go to waste in the current tick because they are not sold
  wasted-prod-cum       ;waste generated: cumulative variable

  utilities-list        ;list with the utilities of each product: it will be used in order to select the best product (with max value of utility). It is reset for each user
  p-whos-list           ;list: it is filled in in parallel with the "utilities-list" and contains the whos of the products whose utility is being calculated

  ; lists with product features
  ; they are the extracted from the csv file containg the info about products. Each list corresponds to a column in the csv file
  p-name-list
  p-price-min-list
  p-price-max-list
  p-sustainability-min-list
  p-sustainability-max-list
  p-quality-min-list
  p-quality-max-list
  p-acceptance-list
  p-shelf-life-list
  p-residual-life-list
  p-cons-per-user-list
  p-color-list
  p-stock-threshold-list

  c-security-stock
  p-RL-baseline
  p-RL-upper-lim

]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;SETUP;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;List of  all the procedures that must be included in the setup process: they will be better defined below
to setup
  clear-all
  file-close-all
  print "*********** NEW SIMULATION ***********"
  ask patches [ set pcolor white ]
  init-globals
  import-data
  read-file-matrix
  creation-users
  creation-companies
  reset-ticks
end

to init-globals
  set threshold-1 (2 / 3)
  set threshold-2 (1 / 3)
  set m1 []
  set users-list []
  set best-products-list []
  set best-companies-list []
  ;set p-net-revenues-list []
  set utilities-list []
  set p-whos-list []


  set c-len-memory 10                                             ;keeps into account 10 ticks of memory in order to calculate company demand forecasting
  set wasted-prod 0
  set wasted-prod-cum 0
  set p-RL-baseline 0.8
  set p-RL-upper-lim 0.2

  ;c-security-stock will be set afterwards
end

;import data from the reprocessing matrix
;The rows of the matrix are 'waste' and then all product classes, with the same wording as the column headings.
to read-file-matrix
    file-close-all
    file-open "Reprocessing_matrix.csv"
    set m1 []
    let i 0
    while [ not file-at-end? ] [
       let row csv:from-row file-read-line
       set row  row
       if i >= 0 [ set m1 lput row m1]
       set i i + 1
    ]
    file-close
end

;import the data of products
to import-data

  ;initialize lists
  set p-name-list []
  set p-price-min-list []
  set p-price-max-list []
  set p-sustainability-min-list []
  set p-sustainability-max-list []
  set p-quality-min-list []
  set p-quality-max-list []
  set p-acceptance-list []
  set p-shelf-life-list []
  set p-residual-life-list []
  set p-cons-per-user-list []
  set p-color-list []
  set p-stock-threshold-list []

  ;import data from csv
  file-close-all
  file-open "Input_data_products.csv"
  let result csv:from-row file-read-line
  let m2 csv:from-file "Input_data_products.csv"
  set n-class-of-products ( length m2 - 1 )
  while [ not file-at-end? ]
  [
    let row csv:from-row file-read-line

    ;insert the imported data into the correct list
    set p-name-list lput item 0 row p-name-list
    set p-price-min-list lput item 9 row p-price-min-list
    set p-price-max-list lput item 10 row p-price-max-list
    set p-sustainability-min-list lput item 11 row p-sustainability-min-list
    set p-sustainability-max-list lput item 12 row p-sustainability-max-list
    set p-quality-min-list lput item 13 row p-quality-min-list
    set p-quality-max-list lput item 14 row p-quality-max-list
    set p-acceptance-list lput item 4 row p-acceptance-list
    set p-shelf-life-list lput item 5 row p-shelf-life-list
    set p-residual-life-list lput item 6 row p-residual-life-list
    ;set p-cons-per-user-list lput item 21 row p-cons-per-user-list
    ;set p-cons-per-user-list [0.05 0.075 0.04 0.04 0.075 0.065 0.05]
    set p-cons-per-user-list [0.15 0.20 0.1 0.05 0.2 0.15 0.1]
    set p-color-list lput item 22 row p-color-list
    set p-stock-threshold-list lput item 23 row p-stock-threshold-list
  ]
  file-close
end

;create users
to creation-users

  create-users n-users
  [
    set xcor random-xcor
    set ycor random-ycor
    set shape "person"
    set color grey
    set utility-of-best-product 0
    set beta random-float 1     ;sustainability weight
    set gamma random-float 1    ;price weight
    set alpha random-float 1    ;quality weight
    set delta 1                 ;FIX acceptance weight
    set omega random-float 1    ;RL/SL weight

    ; each user has a stock of (n-class-of-products) items and sets the initial stock of each class (each element of the list) as a random number between 0 and 5
    set stock n-values n-class-of-products [random 5]
    set buy-bool False                         ; at the beginning the user does not buy
    ;set trigger trigger-baseline + random 5   ;CHECK
    set budget-of-period (5 + random 10)       ;there is a periodic budget per person: it depends on the context (fashion vs food). The budget accumulates and doesn't reset after each tick
    set tot-budget 0                           ;cumulated budget

    ;CHECK
    ;set stock-threshold ( 0.5 + random-float 0.5 )
  ]
end

;create companies
to creation-companies

  ; first, create the companies
  let id 0
  create-companies n-companies [
    set id id + 1
    setxy random-xcor random-ycor
    set color black
    set size 3
    set shape "factory"
    set earnings 0
    set c-ID id
    ;list of (n-class-of-products)-elements in which the initial demand will be calculated using the number of users and the cons-per-user
    set c-demand []

    ;Here the c-demand is setup
    ; HP: For each class of products we have a consumption rate (f.e. 20%), consequently we hypothesize that the (cons-per-user)% of users (f.e. 20%) will buy that specific class of product today
    let i 0
    while [ i < n-class-of-products ] [
      let assuming-consumption item i p-cons-per-user-list                            ;the assuming-consumption uses the consumption rate (cons-per-user) of the specific class of product
      set c-demand lput (( n-users * assuming-consumption ) / n-companies) c-demand   ;it is setup fictitiously with the hypothesized demand (n-users * cons-per-user)/n-companies
      set i i + 1
    ]

    ;Assign behavioural parameters to each company
    set c-price random-float 1                                                        ;Between 0 and 1: it will multiply the price-variability range in order to obtain an intermediate value
                                                                                      ;The lower c-price will be, the cheaper the company will be and viceversa
    set c-sustainability  random-float 1
    set c-quality  random-float 1
    ;c-acceptance is not set as it is a feature attributable only to users

    ;here the c-memory is initialized
    ;At the beginning of the simulation, the sales hystory of the previous 10 periods, is hypothesised as equal to the demand just assumed above.
    ;Therefore the c-memory is set in the following way and the process is reiterated for (c-len-memory) times to fill in the entire list
    ;The difference between c-memory and c-demand is that the first one has integer numbers while the second one doesn't
    set c-memory []
    set i 0
    let j 0
    while [ j < c-len-memory ] [
      let new-memory []
      while [ i < n-class-of-products ] [
        let demand-to-memory int ( 1 + (n-users * item i p-cons-per-user-list / n-companies ) )
        set new-memory lput demand-to-memory new-memory
        set i i + 1
      ]
      set c-memory lput new-memory c-memory
      set j j + 1
      set i 0
    ]
    ;once the support variable "c-new-memory" is integrated in the sales history, then it can be reset for the next tick
    ;Techically, the "c-new-memory" list should be reset to an empty list but, for simplicity in the following lines of code, it is reset to values = zero
    set c-new-memory n-values n-class-of-products [0]
  ]


  ;PRODUCT GENERATION
  ;here it is generated the stock of the company: it will be dependent on the c-memory calculated above (which is the dummy sales history)
  ;Create the number of products according to the modelling hypothesis
  let i 0
  let c-init-stock-list []
  set c-security-stock map [t -> t * 10] p-cons-per-user-list                              ;the company's security stock of class i products, is proportional to the consumption rate of class i
  while [ i < n-class-of-products ] [
    let c-security-stock-i ceiling (item i c-security-stock)
    let c-init-stock-i int ( 1 + (n-users * item i p-cons-per-user-list / n-companies ) )  ;here the initial stock to satisfy the user's demand is calculated with the same assumptions used for c-demand
    set c-init-stock-list lput (c-security-stock-i + c-init-stock-i) c-init-stock-list     ;here the c-init-stock-list is created with items that are the sum of (SS and initial stock forecasted)
    set i i + 1
  ]

  ask companies [
    set i 0
    let my-company self
    let my-id c-ID
    while [ i < n-class-of-products ] [
      hatch-products item i c-init-stock-list [
        set breed products
        set shape "box"
        set color item i p-color-list
        set size 1
        set heading random 359
        fd 3

        ;for each iteration of the while cycle, products of the same class (but with heterogenous attributes) are generated
        set p-name item i p-name-list

        ;each attribute will be generated in the following way:
        ;1. there are a fixed baseline (attribute-min) and a fixed maximum (attribute-max) valid for each class of products
        ;2. The variability of product attributes depends on the deviation, which is the difference between the extremes of the range.
        ;   However, it is also influenced by the specific feature of the company (c-attribute) that produces the product, which can mitigate this range in a more or less strong manner (since it is a random -float[0;1])
        let price-variability ( item i p-price-max-list - item i p-price-min-list ) * [ c-price ] of my-company

        ;3. Given the possible price range for each class, the attribute of new product generated, will assume an attribute equal to the (baseline) + (a random point taken trom the attribute-varibility range)
        set p-price item i p-price-min-list + ( random price-variability )
        ;print (word "p-category: " item i p-name-list word " baseline:" item i p-price-min-list  word " price-variability: " price-variability word " p-price: " p-price)

        let sustainability-variability ( item i p-sustainability-max-list - item i p-sustainability-min-list )
        set p-sustainability item i p-sustainability-min-list + (random sustainability-variability * [ c-sustainability ] of my-company )

        let p-quality-variability ( item i p-quality-max-list - item i p-quality-min-list )    ;review: decide to keep it or not
        set p-quality item i p-quality-min-list + (p-quality-variability * [ c-quality ] of my-company)

        set p-acceptance item i p-acceptance-list  ;review: decide to keep it or not
        set p-shelf-life item i p-shelf-life-list
        set p-residual-life (item i p-shelf-life-list * p-RL-baseline) + ( (random-float p-RL-upper-lim )* item i p-shelf-life-list )
        set p-RL/SL-ratio p-residual-life / p-shelf-life
        ;the logic behind SL and RL is the same used in the "new-products-creation" procedure and will be detailed in that section

        ;the hypothesis is to begin the simulation with only primary products
        set primary-prod 1
        set p-stock-threshold item i p-stock-threshold-list
        set owner-id my-id
        set p-discount 0.9
        set p-sust-increase 1.1
        set p-price-norm 0
        set p-sustainability-norm 0
        set p-quality-norm 0
        set p-acceptance-norm 0
        set p-RL/SL-ratio-norm 0
        set p-utility 0
        set p-init-utility 0
        ;print ( word "p-name "p-name" p-price"p-price " p-sust "p-sustainability  "  p-quality  "p-quality "  p-acceptance  "p-acceptance )

      ]
      set i i + 1
    ]
  ]

end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; GO ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; How simulation will evolve
to go

  ; 1. refresh variables used to make counts
  refresh-variables

  ; 2. the consumer
  user-stock-consumption
  get-normalized-status
  utility-function-management

  ; 3. the product
  residual-life-consumption
  strategy-discount
  strategy-reprocess

  ; 4. the company
  sales-history-update
  demand-assessment
  new-products-creation
  strategy-changing ;check

  tick
end

to refresh-variables

  ask users [
    set buy-bool false
    set color grey
    set tot-budget tot-budget + budget-of-period
  ]
  set best-products-list []
  set best-companies-list []
  set users-list []

end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; CONSUMERS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Here the stock of each user is reduced as products are consumed by the user
;For each class of products, the stock of that class is reduced considering the specific consumption rate of that class (the one imported from the csv file).
;For each iteration of the while cycle, a single class of products is considered the stock (which is a list) is updated with the new amount of stock
to user-stock-consumption
  ask users
  [
    let i 0
    while [ i < n-class-of-products ] [

      let current-stock-i item i stock                                     ;this is the current stock of the class i of products taken into consideration
      let consumption-rate-i item i p-cons-per-user-list                   ;this is the consumption rate of the class i
      let consumption-i (consumption-rate-i) * current-stock-i             ;this is quantity of product consumed in the current tick
      let future-stock-i max list ( current-stock-i - consumption-i ) 0    ;the new quantity of product is the current stock - what has just been consumed. It cannot be a negative number.
      set stock replace-item i stock future-stock-i                        ;the stock is updated with the new quantity
      set i i + 1

    ]
  ]
end

;Here all the weights used in the decision-making process are normalized in view of the calculation of the utility function
;This will provide more stability to the model.
to get-normalized-status

  ;compute for each product the normalized score for price, sustainabilty, quality and acceptance
  ask products
  [
    let my-name p-name
    ;compute the maximum and minumum of each attribute
    ;Since there are several classes of products, the normalization will happen within each class
    let max-sustainability max [ p-sustainability ] of products with [ p-name = my-name ]
    let min-sustainability min [ p-sustainability ] of products with [ p-name = my-name ]
    let max-price max [ p-price ] of products with [ p-name = my-name ]
    let min-price min [ p-price ] of products with [ p-name = my-name ]
    let max-quality max [ p-quality ] of products with [ p-name = my-name ]
    let min-quality min [ p-quality ] of products with [ p-name = my-name ]
    let max-acceptance max [ p-acceptance ] of products with [ p-name = my-name ]
    let min-acceptance min [ p-acceptance ] of products with [ p-name = my-name ]
    let min-p-RL/SL-ratio min [p-RL/SL-ratio] of products with [ p-name = my-name ]
    let max-p-RL/SL-ratio max [p-RL/SL-ratio] of products with [ p-name = my-name ]

    ;here the normalized attributes are calculated
    ifelse max-sustainability - min-sustainability != 0 [ set p-sustainability-norm (p-sustainability - min-sustainability) / (max-sustainability - min-sustainability) ] [ set p-sustainability-norm 0.5 ]  ;REVIEW
    ifelse max-price - min-price != 0 [ set p-price-norm (p-price - min-price) / (max-price - min-price) ] [ set p-price-norm 0.5 ]
    ifelse max-quality - min-quality != 0 [ set p-quality-norm (p-quality - min-quality) / (max-quality - min-quality) ] [ set p-quality-norm 0 ]  ;review: decidere cosa fare con quality
    set p-acceptance-norm 1   ;review
    ifelse max-p-RL/SL-ratio - min-p-RL/SL-ratio != 0 [ set p-RL/SL-ratio-norm (p-RL/SL-ratio - min-p-RL/SL-ratio) / (max-p-RL/SL-ratio - min-p-RL/SL-ratio) ] [ set p-RL/SL-ratio-norm 0.5 ]
  ]

end

;EXPLAIN il casino fatto con le mille liste
;la logica dietro questo pezzo di codice è che, anche se a livello logico, avrebbe senso valutare ai fini dell'acquisto solo i prodotti meno presenti nel mio stock, ai fini di comprare solo ciò che è strettamente necessario,
; nella realtà succede che un utente finisce spesso per comprare anche un prodotto che non serve.
; di conseguenza, l'approccio usato è il seguente:
; 1. prima si calcola l'utilità di tutti i prodotti
; 2. poi correggiamo questa utilità con un fattore che la smorza/amplifica in base all'effettiva necessità di quel prodotto (ovvero nella presenza o meno a stock di prodotti di quella classe)
; 3. si valuta il prodotto migliore (quello con massima utilità) e lo si acquista (se sono rispettati i vincoli di budget)
; nota: questo non implica che un utente compri per forza solo i prodotti che sono necessari.
; 4. l'acquisto avviene solo



to utility-function-management

  ; find the best company according to each user preference
  ; first we define the weights for each user
  ask users
  [
    let my-beta beta ; sust-weight
    let my-gamma gamma ;price-weight
    let my-alpha alpha ; quality-weight
    let my-delta delta ; acceptance-weight
    let my-omega omega ; residual life-weight

    ; initialize global lists
    set utilities-list []
    set p-whos-list []

    let my-stock stock

    ; each user has a different threshold
    ;let my-stock-threshold p-stock-threshold


    ask products
    [

      ; first, compute the utility assumiung that the quantity of stock of the class of products is not relevant (without considering the effective need)

      set p-init-utility ( (p-quality-norm * my-alpha) + (p-sustainability-norm * my-beta) - (p-price-norm * my-gamma)) * (p-acceptance-norm * my-delta) * ((p-residual-life * my-omega) / p-shelf-life)

      ; second, i evaluate how much stock i have for each class of products
      let index-product position p-name p-name-list
      ;print position p-name p-name-list
      let i-stock item index-product my-stock
      let i-stock-threshold item index-product p-stock-threshold-list
      ;print (word "index-product: "index-product word " my-stock: " my-stock)

      ; se ho uno stock target/massimo, calcolo quanto mi manca ad arrivare quel limite e moltiplico quel valore per l'utilità:
      ; se mi mancano tanti prodotti della categoria i--> questo calcolo amplificherà la propensione all'acquisto per quello specifico prodotto
      ; se per una data categoria, ho lo stock che si avvicina al limite --> questo calcolo diminuirà l'utilità
      ; se ho più prodotti rispetto allo stock target,  (1 - i-stock / my-stock-threshold) sarà negativo, di conseguenza prendo il valore 0
      ; così, aggiungiamo un vincolo sui valori che può assumere l'utilità che deve essere >=0

      ;let missing-stock 1 - i-stock / i-stock-threshold

      ;;;;PROVA
      let adjustment-factor 0
      if (i-stock / i-stock-threshold) <= 1 [
        ;es 0.3
        ;adj sarebbe 1.7
        ; se fosse 1+ stock/trhs --> adj = 1.3
        set adjustment-factor ( 1 +  (1 - i-stock / i-stock-threshold) )  ; Amplifica proporzionalmente a quanto manca per raggiungere il threshold
      ]

      ; Se stock-ratio è maggiore o uguale a 1, smorza p-utility
      if (i-stock / i-stock-threshold) > 1 [
        set adjustment-factor  ((i-stock / i-stock-threshold ) - 1); Smorza in modo che il valore non sia mai negativo
      ]



      set p-utility p-init-utility * ( adjustment-factor ) ; FB - fate un bel commentoe per ricordare che cosa voglia dre quest cosa qui, altrimenti me ne dimentico anche io

      set utilities-list lput p-utility utilities-list
      set p-whos-list lput who p-whos-list

    ]


    if (count products != 0)
    [

    let max-utility max (utilities-list)
    let index-score position max-utility utilities-list
    let my-best-product item index-score p-whos-list   ;returns a who
    set utility-of-best-product max-utility
    let best-company ([owner-ID] of products with [who = my-best-product])

    set users-list lput who users-list
    set best-products-list lput my-best-product best-products-list
    set best-companies-list lput best-company best-companies-list


    ;print (word "my BP: " my-best-product word "users-list: " users-list word " best-products-list: " best-products-list word " best-companies-list: " best-companies-list word " best-company: " best-company)
;    ask products
;    [
;      set p-net-revenues-list lput ( ( [p-price] of one-of products with [who = last best-products-list]) - ([p-production-cost] of one-of products with [who = last best-products-list])) p-net-revenues-list
;    ]

;FB - vi prego commenatemi ogni linea di codice, aiutatemi ad aiutarvi
; FB - commentate lungamente sopra ogni funzione che cosa fa e quali sono i processi
; FB - fatevi un disegnino carta e penna di pgni funzione che cosa fa, tipo un diagramma di flusso

    if debug and who < 5 [
      print ( word "who: " who " - s: " precision stock 2 "  - st:" precision p-stock-threshold 2 " - u:" precision utility-of-best-product 2 " t:" precision trigger 2 " |||||| left:" precision ( stock / p-stock-threshold ) 2 " <= right:" precision ( utility-of-best-product * trigger ) 2)
      if max-utility = 0 [ print utilities-list ]
    ]

    let chosen-product products with [who = my-best-product]; trova l'indice del prodotto venduto (nelll'ordine del file CSV)
    let index-product position ( [ p-name ] of one-of chosen-product ) p-name-list ;FB - commentare per ricordare
    let i-stock item index-product my-stock
    let i-stock-threshold item index-product p-stock-threshold-list
    let i-price [p-price] of one-of chosen-product
    ;let stock-ratio max list ( 1 - i-stock / i-stock-threshold ) 0
    ;let stock-ratio  1 - i-stock / stock-threshold


;   if (i-stock / i-stock-threshold <= (utility-of-best-product * trigger)) and (i-price <= tot-budget) [
    if ((1 - i-stock / i-stock-threshold ) * trigger <= (utility-of-best-product )) and (i-price <= tot-budget) [  ; se lo mettiamo --> valutare che lo stock ratio non sia negativo e che abbia il comportamento
        ;in questo caso, inserendo lo stock ratio nell'equazione di acquisto, stiamo dicendo che:
        ; la mia propensione all'acquisto (ovvero il trigger) è influenzata dalla mancanza di prodotti nel mio stock : se mi mancano dei prodotti, il trigger verrà amplificato; altrimenti verrà smorzato
        ; NB: il trigger è un random-float 1
        ; allo stesso tempo, la mancanza di prodotti nel mio stock guida la scelta del mio prodotto migliore (nel senso che, se ho bisogno di frozen food, l'utilità di quello specifico prodotto verrà incrementata)
        ; SULLA CARTA QUESTO RAGIONAMENTO DOVREBBE AVERE SENSO
   ; if (trigger <= (utility-of-best-product )) and (i-price <= tot-budget) [
          ; in questo caso NON inseriamo lo stock ratio
          ; la formula non sarebbe ridondante visto che la necessità di un prodotto è già inglobata all'interno dell'utilità grazie all'adjustement factor
          ; trigger <= utility iniziale * adjustement factor
;    if (i-price <= tot-budget) [
      set buy-bool True ; the user buys an item
      set color pink
      ;print (word "tick" ticks word "who" [who] of self word " stock-ratio "(i-stock / i-stock-threshold) word "  utility-of-best-product * trigger  " (utility-of-best-product * trigger) )

      set chosen-product one-of chosen-product
      let chosen-company companies with [c-ID = [owner-ID] of chosen-product ]
      set tot-budget tot-budget - ([p-price] of chosen-product)

        ;ora abbiamo c-memory che ha lo storico e c-new-memory = []

      set stock replace-item index-product stock ( i-stock + 1 )
      ;print (word "tick " ticks " stock-i post acquisto: " stock)

      ask chosen-company [
        ; add the earnings
        set earnings earnings + [ p-price ] of chosen-product ;FB poi ci saranno da mettere anche i costi di produzione

        ; add the memory in the correct position
        let c-new-memory-to-add item index-product c-new-memory ; prendo l'elemento da aumentare di uno dalla memoria temporanea
        set c-new-memory-to-add c-new-memory-to-add + 1 ; lo aumento di 1 perché ho venduto 1
        set c-new-memory replace-item index-product c-new-memory c-new-memory-to-add ; sostituisco con il valore da cui l'ho preso

      ]

        ;print (word "c-ID: " [owner-id] of chosen-product " - c-sust: " [c-sustainability] of chosen-company " - c-price: " [c-price] of chosen-company " - p-name: " [p-name] of chosen-product " - p-price: " [p-price] of chosen-product)

      ask chosen-product [ die ]
    ]
      ;print (word "tick: " ticks " who" [who] of self " i "index-product " stock-ratio: "precision (i-stock / i-stock-threshold) 2 " i-stock: " precision i-stock  2 " i-stock-threshold: " precision i-stock-threshold 2 "  result ut*trig " precision (utility-of-best-product * trigger) 2 "  utility-of-best-product " (precision utility-of-best-product 2) "  trigger: "trigger " buy-bool "buy-bool "budget-post-acquisto: "tot-budget)
    ]
  ]


end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; PRODUCT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;The products generated by companies, if not sold, remain in stock in the company
;Therefore, their residual life decreases, and gets closer to the expiration date/end of season (depending on the context)
to residual-life-consumption
  ask products
  [
    set p-residual-life (p-residual-life - 1)
    ;print (word "prod name: " p-name " prod RL: " p-residual-life " prod SL: " p-shelf-life)
    if p-residual-life = 0 [ die ]
  ]
end

;;;;SHORT TERM STRATEGIES
;Before letting a product die and thereby making it a waste, a company can adopt strategies to incentivize its sale.
;The first is to reduce the product price, while the second will act on the second attribute (product sustainability).
;These strategies will be applied once the product reaches 2 thresholds positioned in its useful life

to strategy-discount
  ask products with [ p-residual-life <= (threshold-1 * p-shelf-life)]
  [
    set p-price p-discount * p-price
  ]
end


;Hypothesis 1: the entire unit of the product is either reprocessed or goes to waste.
;Hypothesis 2: once excedeed the threshold-2, products will be either reprocessed (according to the % expressed in the matrix) or will go to waste
;Starting from the reprocessing matrix (csv), its dimensions are evaluated.
;The matrix is structured as follows: rows of the matrix contain the label 'waste' and then the name of all product classes; the same labels are used as the column headings.
;The remaining cells contain a number representing the percentage of products in that class that are reprocessed.
;Reprocessing has as its starting class the one indicated in the row, and as its destination the class indicated in the corresponding column.
to strategy-reprocess
  let num-rows length  m1
  let num-columns length first m1
  ;print (word "numero righe: " num-rows word " numero colonne: " num-columns)

  let i 2 ;rows
  let j 0 ;columns

  ;for each row, the products belonging to the corrisponding class are evaluated to be reprocessed.
  while [ i < num-rows ]
  [
    let p-name-to-be-transformed item j item i m1
    ;print (word "numero agenti totali: " count products)

    ;here only the products that satisfy the RL criteria, will be reprocessed
    ask products with [p-name = p-name-to-be-transformed and p-residual-life <= (threshold-2 * p-shelf-life) and primary-prod = 1]
      [
        ;print (word "numero agenti da riprocessare: " count products word " RL:  " mean [p-residual-life] of products word " t2* SL: " threshold-2 * (mean [p-shelf-life] of products) )
        set j j + 1 ;j=1

        ;first, the waste generated is managed
        let p-waste item j item i m1
        let n-products-to-transform (count products)
        ;print ( word "n-class-of-products-to-transform" n-class-of-products-to-transform )

        if (p-waste > 0)
        [
          let n-products-to-waste ceiling (n-products-to-transform * p-waste)                          ;the number of products to waste, is rounded up to an integer number

          set wasted-prod n-products-to-waste
          set wasted-prod-cum wasted-prod-cum + wasted-prod

          ask n-of n-products-to-waste products [die]
          ;print (word p-name-to-be-transformed word "total-products: "total-products word "  n-products-to-transform: " n-products-to-transform word "  n-products-to-waste: " n-products-to-waste word "  prodotti rimasti: " count products)
        ]

        ;second, the actual reprocessing is performed on "n-products-to-reprocess" units of products
        ;The while is performed until (num-column - 1) because, as the procedure enters the while cycle, j is incremented of 1 unit, so the last iteration will happen with j= index of the last column
        while [j >= 1 and j < (num-columns - 1)]
        [
          set j j + 1
          let percentual-reprocessing item j item i m1

          if (percentual-reprocessing > 0 )
          [
            let n-products-to-reprocess floor (n-products-to-transform * percentual-reprocessing)       ;this quantity is the complementary of "n-products-to-waste"

            hatch n-products-to-reprocess
            [
              ;Setup the attributes of the reprocessed product (k)
              set p-name (item j item 0 m1)
              set primary-prod 0
              let p-name-k p-name                     ;p-name of the reprocessed product
              let k position p-name-k p-name-list
              ;print (word "p-name-k: " p-name-k word " item: " position p-name-k p-name-list)

              ;once identified the name of the destination class of the reprocessing, the corresponding attributes (price, sust...etc) are retrieved
              ;price and residual life of reprocessed products are set as mean values of the class.
              let price-min-k item k p-price-min-list
              let price-max-k item k p-price-max-list
              let mean-price-k (price-min-k + price-max-k) / 2
              set p-price mean-price-k
              let p-mean-residual-life-k (item k p-residual-life-list) ; there is no max/min residual life in the lists of residual lives
              set p-residual-life p-mean-residual-life-k

              ;sustainability of reprocessed products is always increased with respect to the destination class, as the reprocessing extends the shelf life and therefore reduces the probability of becoming waste
              ;reprocessed products are perceived as more sustainable than primary products of the same class, as they are generated from material that would have become waste.
              let sustainability-min-k item k p-sustainability-min-list
              let sustainability-max-k item k p-sustainability-max-list
              let mean-sustainability-k (sustainability-min-k + sustainability-max-k) / 2
              set p-sustainability p-sust-increase * mean-sustainability-k
            ]
            let n-products-to-die n-products-to-reprocess
            ;print (word "n-products-to-die: " n-products-to-die " n-products-to-reprocess: " n-products-to-reprocess " n-products-to-reprocess: " n-products-to-reprocess " n-products  " count products with [p-name = p-name-to-be-transformed and p-residual-life <= (threshold-2 * p-shelf-life)])
            ask n-of n-products-to-die products [die]

          ]
        ]
        set j 0
    ]
    set i i + 1

  ]

end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; COMPANY ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;c-new-memory: represents the purchases of the current tick and is added to the list
;In the utility procedure, after all users have decided whether to buy or not, the list of all sales of the current tick -grouped by class of products - is ready (c-new-memory)
;Now it must be incorporated within the sales history (c-memory)
;C-memory is a list of 10 sublists: each sublist has a number of elements equal to n-class-of-products and represents the purchases done by users for each class of products in a specific tick
to sales-history-update
  ask companies [
    set c-memory fput c-new-memory c-memory                 ;c-new-memory is added as first sublist: c-memory= [[c-new-memory] [sublist 1]...etc [sublist 11]]
    set c-memory but-last c-memory                          ;but the list c-memory must mantain the same length, so the last element is removed: c-memory= [[c-new-memory] [sublist 1]...etc [sublist 10]]
    set c-new-memory n-values n-class-of-products [0]       ;Now that the dummy memory (c-new-memory) has been saved in c-memory, it can be reset to be used in the next tick
    ;print (word "c-id" c-id word " c-price: " c-price word "   c-memory" c-memory)
  ]
end

;Now, companies have sold products to users and updated their sales history: consequently, based on the history, they must now estimate how many units to produce to meet the expected demand for the next tick
;The assumption is that demand for companies is expected to be in line with the average purchases of the latest 10 periods
to demand-assessment
  ask companies [
    let i 0                                                                                    ;i= each class of products
    while [ i < n-class-of-products ] [
      ;In order to later calculate the average demand of class i, the sum of all sales of products of class i in all the periods saved in c-memory, must be calculated
      let n-product-sold-class-i 0
      let k 0                                                                                  ;k= represents the index of each sublist, therefore it indicates a tick

      ;Now, let's analyse iteratively the list c-memory of length = c-len-memory (10)
      ;Takes the history of the last 10 days and adds up the quantity sold for each product over the last 10 periods
      while [ k < c-len-memory ] [
        set n-product-sold-class-i n-product-sold-class-i + item i ( item k c-memory )
        set k k + 1
      ]
      ;At the end of this while cycle, we know how much of a class of products has been sold in the latest periods

      ;Now the average sales per day/month for each class of products can be calculated
      let avg-product-sold-class-i 0
      set avg-product-sold-class-i ceiling ( n-product-sold-class-i / c-len-memory )
      set c-demand replace-item i c-demand avg-product-sold-class-i                            ;now that the average demand of class i has been calculated, it can be inserted in the c-demand list
                                                                                               ;(c-memory is updated each tick, and so c-demand does since it depends on c-memory)
      set i i + 1
    ]
  ]
end

;Now that the demand has been assessed, companies respond by creating the needed number of products for each class
to new-products-creation
  ask companies [
    let j 0                                                                                   ;j= class of products
    let my-company self                                                                       ;returns "who" of the company
    let my-id c-ID
    while [ j < n-class-of-products ] [
      let c-stock-j count products with [ owner-id = my-id and p-name = item j p-name-list ]
      let c-production-j max list (item j c-demand + item j c-security-stock - c-stock-j) (0)
      ;print (word "ticks" ticks word "  c-id  " c-id word "  p-name  " item i p-name-list word "  c-i-stock  "  c-i-stock word " c-i-demand  "c-i-demand word "  i-production  " i-production )
      ;print (word "ticks: " ticks " class: " j " production: " c-production-j )

      ;now, a number of products equal to the forecasted production is generated
      hatch-products c-production-j [
        set breed products
        set shape "box"
        set color item j p-color-list
        set size 1
        set heading random 359
        set primary-prod 1
        fd 3

        set p-name item j p-name-list
        let price-variability ( item j p-price-max-list - item j p-price-min-list ) * [ c-price ] of my-company
        set p-price item j p-price-min-list + ( random price-variability )

        let sustainability-variability ( item j p-sustainability-max-list - item j p-sustainability-min-list )
        set p-sustainability item j p-sustainability-min-list + (random sustainability-variability * [ c-sustainability ] of my-company )

        let p-quality-variability ( item j p-quality-max-list - item j p-quality-min-list )
        set p-quality item j p-quality-min-list + (p-quality-variability * [ c-quality ] of my-company) ;review
        set p-acceptance item j p-acceptance-list

        ;p-shelf-life is assumed as the same for all products of the same class
        ;p-residual-life represents the remaining life of the product at the time it arrives at the shop. It is therefore heterogeneous as it takes into account all those real factors that may cause
        ;the product to arrive at the shop at a different time with respect to the moment it is actually produced (e.g. lead time, responsiveness of the company... etc).
        ;In order for the product to remain competitive, not too much time must pass from the moment it is produced and when it reaches the shop.
        ;Consequently the minimum limit for RL is set at 80% of the SL (and the maximum will be 100% of the SL)
        set p-shelf-life item j p-shelf-life-list
        set p-residual-life (item j p-shelf-life-list * p-RL-baseline) + ( (random-float p-RL-upper-lim )* item j p-shelf-life-list )
        set p-RL/SL-ratio p-residual-life / p-shelf-life
        set owner-id my-id
      ]
      set j j + 1
    ]
  ]


end

to check
  let total-products count products
  let primary-prod-1 count products with [primary-prod = 1]
  let primary-prod-0 count products with [primary-prod = 0]
  ifelse total-products = (primary-prod-1 + primary-prod-0)
  [ print "ok" ]
  [ print "error" ]
end

;;;;LONG TERM STRATEGIES
to strategy-changing
;solo strategia di sostenibilità:
  ; esempio food: collaborazioni esselunga - altromercato (linea prodotti sostenibili) / per sostenibilità sociale--> queste azioni aumentano la sostenibilità percepita delle compagnie
  ; esempio fashion: zara dichiara di produrre i suoi capi con x% in meno di acqua/risore--> queste azioni aumentano la sostenibilità percepita delle compagnie

end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; REPORT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to-report safe-divide [numerator denominator]
  if denominator = 0
  [
    report 0
  ]
  report numerator / denominator
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
0
0
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
28
24
91
57
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
95
24
158
57
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
2.0
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
50
15.0
5
1
agents
HORIZONTAL

MONITOR
997
18
1095
79
Mean price
precision mean ( [p-price] of products ) 2
17
1
15

MONITOR
997
105
1155
166
Mean sustainability
precision mean [ p-sustainability ] of products  2
17
1
15

MONITOR
999
187
1180
248
Avg Stock of Products
precision mean [ mean stock ] of users 2
17
1
15

BUTTON
161
24
244
57
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
663
181
976
335
User stock of products
NIL
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [ mean stock ] of users"

SWITCH
18
194
121
227
debug
debug
1
1
-1000

TEXTBOX
109
56
259
81
SALVA!!!!!!!!
20
0.0
1

PLOT
662
339
979
523
Company stock of producs
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
"default" 1.0 0 -16777216 true "" "plot count products"

MONITOR
379
548
571
609
TOT number of products
count products
15
1
15

PLOT
985
428
1208
603
N-products reprocessed vs normal
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count products"
"primary" 1.0 0 -2139308 true "" "plot count products with [primary-prod = 1]"
"reprocessed" 1.0 0 -10899396 true "" "plot count products with [primary-prod = 0]"

SLIDER
18
242
190
275
trigger-baseline
trigger-baseline
0
100
1.0
1
1
NIL
HORIZONTAL

MONITOR
999
254
1126
323
wasted-prod 
wasted-prod
17
1
17

PLOT
1228
427
1442
601
wasted-products
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
"default" 1.0 0 -955883 true "" "plot wasted-prod "

MONITOR
1205
264
1387
325
MIN stock of products
precision min [ min stock ] of users 2
17
1
15

MONITOR
1205
325
1390
386
MAX stock of products
precision max [ max stock ] of users 2
17
1
15

PLOT
663
13
982
181
N. of buyers
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
"default" 1.0 0 -16777216 true "" "plot count (users with [buy-bool = true])"

MONITOR
290
358
463
403
Products Class 1 (Fruits & Veg)
count products with [p-name = item 0 p-name-list]
17
1
11

MONITOR
290
405
464
450
Products Class 2 (Frozen Food)
count products with [p-name = item 1 p-name-list]
17
1
11

MONITOR
289
453
463
498
Products Class 3 (Sweets)
count products with [p-name = item 2 p-name-list]
17
1
11

MONITOR
287
501
464
546
Products Class 4 (Canned Food)
count products with [p-name = item 3 p-name-list]
17
1
11

MONITOR
469
359
626
404
Products Class 5 (Meat)
count products with [p-name = item 4 p-name-list]
17
1
11

MONITOR
471
408
626
453
Products Class 6 (Fish)
count products with [p-name = item 5 p-name-list]
17
1
11

MONITOR
470
455
627
500
Products Class 7 (Pasta)
count products with [p-name = item 6 p-name-list]
17
1
11

@#$#@#$#@
## NOTA BENE
- nota: netlogo è case sensitive, quindi può essere necessario implementare un check sul nome dei prodotti inseriti nella matrice
- in strategy-reprocessing: per chiamare l'elemento i,j devo scrivere "item j item i m1"


### Problemi da risolvere

#### problemi  minori
- capire se usare net revenue o earnings-> ne consegue se tenere production cost o meno
- capire cosa fare con p-quality e p-acceptance
- capire se vanno bene le SS per come sono impostate ora

#### problemi maggiori

- limite di acquistare 1 solo prodotto per volta è limitante ?
	- forse  si potrebbe risolvere con la poisson (ovvero ogni tot, la  treshold 		si alza rispetto al suo valore std = l'utente si fa tentare perché è debole!!)
- venire a capo da tutti i problemi di funzione utilità e equazione di acquisto
	- capire se utilità e stock ratio possono essere negativi
	- scegliere giusta equazione di acquisto
	- capire ordine di grandezza giusto di trigger e stock threshold



## Cose modificate rispetto all'ultimo incontro:

- introdotto un adjustement factor che va a sostituire questa parte: 
old: p-utility p-init-utility * ( 1 - i-stock/i-stock-threshold )
new: p-utility p-init-utility * ( adjustment-factor )

- il reprocessing avviene una volta superata una certa soglia: per il food è i 2/3; per il fashion è 0/ più bassa (se tenere una threshold != 0 e una =0 non è un problema a livello concettuale, sarebbe la soluzione più coerente con la realtà; tuttavia tenerle entrambe != 0 sarebbe più elegante)

#### products
- Cambiato il modo in cui settare prezzo, qualità, sostenibilità dei prodotti nuovi generati:  abbiamo introdotto price-variability,...etc
	- let price-variability ( item j p-price-max-list - item j p-price-min-list ) 		* [ c-price ] of my-company
	- set p-price item j p-price-min-list + ( random price-variability )
- in fase di normalizzazione delle variabili usate per calcolare l'utilità, se il valore min e il valore max sono uguali, allora settiamo il valore normalizzato a 0.5 (Non più 1 come prima)
- la stock-threshold non è più uguale per ogni utente ma è caratteristica di ogni classe di prodotti (ora viene importata dal csv)
- abbiamo tolto p-id (che era ridontante rispetto al who) dal modello e dal csv e altre variabili non utili (come p-amount e primary prod) dal csv

#### companies
- abbiamo aggiunto le SCORTE DI SICUREZZA: hanno avuto un grande impatto (prima infatti, non essendoci SS, gli utenti finivano per non comprare nulla perché i prodotti non venivano generati)
- abbiamo verificato in diversi punti il check compartimentale
- la shelf life è uguale per tutti i prodotti della stessa classe che vengono generati: le aziende non competono su ciò
- p-residual-life rappresenta la vita residua  del prodotto nel momento in cui quet'ultimo arriva a negozio. di conseguenza è eterogenea in quanto tiene conto di tutti quei fattori reali che possono causare l'arrivo del prodotto a negozio in un momento diverso da quando viene effettivamente manufactured (es: lead time, responsiveness of the company...etc).
Per fare in modo che il prodotto rimanga competitivo, non deve passare troppo tempo da quando viene manufactured a quando raggiunge il negozio. di conseguenza il limite minimo per la RL viene settato all'80% della SL (e il massimo sarà il 100% della SL)
Abbiamo ipotizzato che, senza questo  "stratagemma" RL/SL sarebbe stato un rapporto meno eterogeneo
- 

#### users
- aggiunto aggiunto un budget per ogni utente


## IPOTESI MODELLISTICHE
- idealmente il "consumo" dello stock degli utenti e la riduzione della RL dei prodotti a scaffale nei negozi, dovrebbero avvenire contemporaneamente (o prima o dopo l'azione di acquisto). Nel modello avvengono in modo disallineato per una maggiore semplicità e schematicità delle procedure del codice

### users
- il trigger è la preferenza di acquisto per ciascun utente generale. Gli utenti hanno trigger eterogenei
- un utente compra solo un prodotto per ciascun turno, indipendentemente dalle quantità (è un modello teorico, ma vi dovete laurerare)

### products
- ogni agente prodotto rappresenta un "batch di prodotto" ed è una quantità comprabile da un utente. Ogni batch di prodotto vale un'unica unità
- quindi, ciascun prodotto ha una classe specificia di appartenenza che rappresenta la sua categoria (food and vegetables, canned food, ... oppure t-shirt, pantaloni, ...)
- la normalizzazione va fatta solo tra prodotti della stessa classe (non posso normalizzare il prezzo di una mela con il prezzo della carne) 
- la shelf life è uguale per tutti i prodotti dello stesso tipo, le aziende non competono su ciò (la pasta di diverse compagnie ha durata uguale oppure la durata delle stagioni nel fashion è uguale a parità di classe di prodotti)
- il reprocessesing avviene solo con vita residua >= 0 (e RL<= alla soglia di threshold-2 * shelf life)
- nel reprocessing, un'unità intera di prodotto di partenza dà vita ad un'unità intera di prodotto riprocessato
- date x unità di prodotti candidati al riprocessamento, solo la percentuale indicata nella matrice m1, verrà effettivamente riprocessata. Le restanti unità diventano waste
- la produzione delle aziende è fatta in modo che producano la domanda di ciascun prodotto meno lo stock che hanno già
- la simulazione inizia con solo prodotti primari
- il reprocessing può avvenire solo per prodotti primari (= un prodotto non può essere riprocessato più di una volta)

### companies
- la domanda prevista dalle aziende per ciascun prodotto all'inizio è il prodotto fra il consumo pro-capite per ciascun ∆t di ciascun prodotto e il numero di utenti (assunzione ragionevole ma ovviamente eroica)
- le aziende all'inizio hanno uno stock pari a n-utenti * consumo / n-aziende, quindi la propria quota iniziale fittizia
- le aziende hanno una memoria di lunghezza fissa (lo storico considera lo stesso numero di periodi)
- la memoria iniziale delle aziende riguardo alla domanda passata è n-utenti * consumo / n-aziende
- le aziende hanno capacità produttiva infinita
- le scorte di sicurezza sono omogenee tra tutte le compagnie
- la domanda prevista dalle compagnie si assume in linea con gli acquisti medi degi ultimi 10 periodi











## HOW IT WORKS

#### Durante il go

- simula il consumo di stock dell'utente
- decide se comprare o meno, e nel caso sceglie da chi comprare
- calcola la vita residua di tutti in prodotti a scaffale
- se la vita residua è sottosoglia, riprocessa


- extra modello (da fare per la tesi): disegnare grafo sulla base della matrice aggiornata
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
