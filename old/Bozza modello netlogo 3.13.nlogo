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
  p-shelf-life
  p-residual-life
  p-RL/SL-ratio
  p-production-cost
  owner-ID
  primary-prod
  discounted        ;false or true

  ;used for utility calculations
  p-price-norm
  p-sustainability-norm
  p-quality-norm
  p-RL/SL-ratio-norm
  p-utility
  p-init-utility

 ]

users-own
[
  alpha
  beta
  gamma
  alpha-norm                ;linked to quality
  beta-norm                 ;linked to sustainability
  gamma-norm                ;linked to price
  epsilon


  stock                ;this is the stock of products of each user (it is a list of (n-class-of-products) items)
  trigger              ;Review:  used to evaluate whether to buy

  ;best-company
  utility-of-best-product
  buy-bool             ;it is a boolean variable: if true, the user is buying. If false the user the opposite
  u-stock-threshold
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
  earnings             ;sum of earnings of all the products sold in the current tick.
  c-production-cost    ;sum of p-production-cost of all the products sold in the current tick.
  c-revenues           ;earning - c-production cost: it is calculated for each tick
  c-revenues-list      ;it is a list of maximum length = length-revenues-list (it is updated in each period). each item is the revenue per product of that period (day/month...etc)
  my-target-revenues    ;it is the revenue to  which the company aims: if not reached it activates the company's sustainability strategy. It is updated every (length-revenues-list) ticks.

  ;companies memory
  c-memory             ;List of lists - is the sales history of the company and tracks the sales grouped by class of products for 10 periods: the first element (the first sublist) is the most recent one.
                       ;It is used to take decisions regarding how much to produce and to keep as stock.
  c-new-memory         ;List - it is a support variable used to calculate for each class, the sum of bought products. It represents the c-memory of the current tick.
                       ;It will be used to update the actual memory (c-memory) by becoming the first sublist. Therefore the last element will be removed in order to keep the main memory of length 10.
  c-sust-increase      ;increase in c-sustainability due to the company's sustainability strategy
  c-sust-strategy-memory ;it is a list that will be used to track the frequency with which the sustainability strategy is put into act: its elements are either 0 or 1
  tot-demand
]

globals [

  threshold-1           ;will be used for the reduction of price
  threshold-2           ;will be used for the reprocessing procedure
  m1                    ;matrix used to import data regarding the reprocessing
  users-list
  best-products-list    ;global list which saves the who of the best product chosen by each user
  best-companies-list   ;global list which saves the c-ID of the company which produces the best product
  n-class-of-products
  c-len-memory          ;length of the list c-memory: it indicates the number of sublists present in c-memory. Each sublist represents a tick
  wasted-prod           ;products that go to waste in the current tick because they are not sold
  wasted-prod-cum       ;waste generated: cumulative variable

  utilities-list        ;list with the utilities of each product: it will be used in order to select the best product (with max value of utility). It is reset for each user
  p-whos-list           ;list: it is filled in in parallel with the "utilities-list" and contains the whos of the products whose utility is being calculated

  ; lists with product features
  ; they are the extracted from the csv file containg the info about products. Each list corresponds to a column in the csv file
  p-name-list
  p-prod-cost-min-list
  p-price-max-list
  p-sustainability-min-list
  p-sustainability-max-list
  p-quality-min-list
  p-quality-max-list
  p-shelf-life-list
  p-residual-life-list
  p-cons-per-user-list
  p-color-list
  p-stock-threshold-list  ;this list will only be used in the setup procedure in order to set the users threshold (u-stock-threshold)

  c-security-stock
  p-RL-baseline

  delta                                 ;it is a factor that indicates how much the production cost (and consequently the price) increases as sustainability of the product improves
  omega                                 ;it is a factor that indicates how much the production cost (and consequently the price) increases as quality of the product improves
  exponent                              ;it is the exponent used in the utility function.

  died-products                         ;it is used to plot the number of products that die after RL=0
  bought-products


  ;used in the strategy-discount procedure
  p-discount                             ;It must be set according to the minimum-revenue-% in order to avoid negative revenues after discounting the product.

  minimum-revenue-%                      ;used in order to set the minimum price.

  chosen-prod-sust-list                  ;this global variable is used for a plot

  ;used in the strategy-reprocess procedure
  p-sust-increase                        ;it is the increase in sustainability of a reprocessed product determined by the reprocessing, with respect to the max sustainability of primary products belonging to the same class
  sust-increase-adj-factor               ;is a variable that will be used to keep into account the improvement in the reprocessing process, that is a direct response to the users' increasing awareness in sustainability
  sust-increase-adj-factor-per-tick
  p-quality-decrease

  ;used in the company-sustainability-strategy
  length-revenues-list                   ;it represents after how much time the companies evaluate whether to apply the company-sustainability-strategy
  g-total-revenues-list                  ;it is a global list containing the total revenues of each company in the moment of evaluation of the c-sustainability-strategy. It has as many elements as n-companies
  c-strategy-frequency                   ;it is the frequency with which the company is authorized to activate the sustainability strategy
                                         ;f.e.: a company evaluates the strategy every year but can activate it only every 3 (to limit the application)
  beta-adj-factor                        ;is a variable that will be used to keep into account that, the increasing awareness regarding sustainability over time, translates in an increasing weight for
                                         ;the sustainability factor when purchasing
  beta-adj-factor-per-tick               ;it is the increment per tick of beta-adj-factor: it is directly proportional to the granularity of the unit of time represented by the tick



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
  setup-cons-per-user-rates
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
  set utilities-list []
  set p-whos-list []


  set c-len-memory 10                                             ;keeps into account 10 ticks of memory in order to calculate company demand forecasting
  set wasted-prod 0
  set wasted-prod-cum 0
  set p-RL-baseline 0.8

  set delta 0.1
  set omega 0.1
  set exponent 0.2
  set length-revenues-list 365                                  ;review: it depends on te context (food vs fashion)
  set died-products 0
  set bought-products 0
  set minimum-revenue-% 0.20
  set p-discount 0.9
  set p-sust-increase 1.1
  set p-quality-decrease 0.9
  set g-total-revenues-list []

  set chosen-prod-sust-list []
  set c-strategy-frequency 3                                     ;it is considered equal both in the food and fashion sectors

  set beta-adj-factor 1
  set beta-adj-factor-per-tick 0.00001                           ;it depends on the sector (food vs fashion) and the granularity of the unit of time of the tick
  set sust-increase-adj-factor 1
  set sust-increase-adj-factor-per-tick beta-adj-factor-per-tick * (p-sust-increase - 1)  ;Since the sust-increase comes from the product's sustainability improvement due to the rise in beta
                                                                                          ;(linked to better reprocessing), the goal is to match the sust-increase rate with beta's growth.
  ;c-security-stock is a global variable but will be set in the "creation-companies" section
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
  set p-prod-cost-min-list []
  set p-price-max-list []
  set p-sustainability-min-list []
  set p-sustainability-max-list []
  set p-quality-min-list []
  set p-quality-max-list []
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
    set p-prod-cost-min-list lput item 8 row p-prod-cost-min-list
    set p-price-max-list lput item 9 row p-price-max-list
    set p-sustainability-min-list lput item 10 row p-sustainability-min-list
    set p-sustainability-max-list lput item 11 row p-sustainability-max-list
    set p-quality-min-list lput item 12 row p-quality-min-list
    set p-quality-max-list lput item 13 row p-quality-max-list
    set p-shelf-life-list lput item 4 row p-shelf-life-list
    set p-residual-life-list lput item 5 row p-residual-life-list
    ;set p-cons-per-user-list lput item 12 row p-cons-per-user-list
    ;set p-cons-per-user-list [0.05 0.075 0.04 0.04 0.075 0.065 0.05]
    ;set p-cons-per-user-list [0.15 0.20 0.1 0.05 0.2 0.15 0.1]
    set p-color-list lput item 13 row p-color-list
    set p-stock-threshold-list lput item 14 row p-stock-threshold-list
  ]
  file-close
end

; this is used in order to randomly setup the consumption rates of each class of products while keeping in mind the limit on the total sum of all rates
;first the rates are set randomly
;then they are "normalized"
to setup-cons-per-user-rates
  ; Step 1: Create a list with 7 random consumption rates
  let base-value 1  ; Questo è il valore di base da cui partire
  let perturbation 0.60  ; Questo rappresenta il disturbo massimo applicabile
  set p-cons-per-user-list n-values 7 [base-value + random-float perturbation - perturbation / 2]
  ;set p-cons-per-user-list n-values n-class-of-products [random-float 1]
  ;Step 2: Calculate the sum of the rates
  let total (sum p-cons-per-user-list)

  ;Step 3: Normalize the rates so their sum equals the limit (e.g., 0.7)
  let limit limit-cons-per-user
  let normalized-rates map [rate -> (rate / total) * limit] p-cons-per-user-list
  set p-cons-per-user-list normalized-rates

  ; Step 4: Use the normalized rates as you need
  print normalized-rates
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


    set alpha random-float 1    ;quality weight
    set beta random-float 1     ;sustainability weight
    set gamma random-float 1    ;price weight
    set alpha alpha
    set beta beta
    set gamma gamma
    let sum-weights alpha + beta + gamma

    ;And now the actual weights that will be used in the utility function are calculated
    set alpha-norm alpha / sum-weights
    set beta-norm beta / sum-weights
    set gamma-norm gamma / sum-weights
    set epsilon random-float 1                 ;this variable doesn't need to be normalized as it is a multiplication factor

    ; each user has a stock of (n-class-of-products) items and sets the initial stock of each class (each element of the list) as a random number between 0 and 5
    set buy-bool False                         ;at the beginning the user does not buy
    set trigger random-float trigger-max       ;the trigger represents the willingness to buy, therefore it is randomly set between 0 and trigger-max:
                                               ;(f.e. 2)this means that the user can choose to buy even until its stock is already equal to the 200% of its stock threshold
                                               ;(f.e. 1.5)this means that the user can choose to buy even until its stock is already equal to the 150% of its stock threshold
                                               ; this is the extreme case which is only verified when utility = 1

    set u-stock-threshold []                   ;this is a list containing the threshold for each class of products for each specific user
    set stock []
    let i 0
    while [i < n-class-of-products][
      let threshold-class-i random (item i p-stock-threshold-list)
      set u-stock-threshold lput threshold-class-i u-stock-threshold
      set stock lput threshold-class-i stock
      set i i + 1
    ]

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

    set c-ID id
    set c-demand []                                                  ;list of (n-class-of-products)-elements in which the initial demand will be calculated using the number of users and the cons-per-user

    set c-sust-increase 1.1                                                         ;Increase in c-sustainability due to the strategy: now it is equal for all companies but it could become heterogeneous
    set earnings 0
    set c-production-cost 0
    set c-revenues 0
    set c-revenues-list []
    set c-sust-strategy-memory n-values c-strategy-frequency [0]                    ;the list is initialized in this way so that, at the first tick, it is possible to evaluate the sublist of (length - c-strategy-frequency)
    set my-target-revenues 0                                                        ;It will be calculated in that specific time because the sustainability strategy depends on the situation
                                                                                    ;in the moment of evaluation and so does this target.

    ;Here the c-demand is setup
    ; HP: For each class of products we have a consumption rate (f.e. 20%), consequently we hypothesize that the (cons-per-user)% of users (f.e. 20%) will buy that specific class of product today
    let i 0
    while [ i < n-class-of-products ] [
      let assuming-consumption item i p-cons-per-user-list                            ;the assuming-consumption uses the consumption rate (cons-per-user) of the specific class of product
      set c-demand lput (( n-users * assuming-consumption ) / n-companies) c-demand   ;it is setup fictitiously with the hypothesized demand (n-users * cons-per-user)/n-companies
      set i i + 1
    ]

    ;Assign behavioural parameters to each company
    set c-price 0.5 + random-float 0.5                                                        ;Between 0.5 and 1: it will multiply the price-variability range in order to obtain an intermediate value
                                                                                      ;The lower c-price will be, the cheaper the company will be and viceversa
    set c-sustainability  random-float 1
    set c-quality  random-float 1

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
        ;For p-sustainability and p-price:
        ;1. there are a fixed baseline (attribute-min) and a fixed maximum (attribute-max) valid for each class of products.
        ;2. The variability of product attributes depends on the deviation, which is the difference between the extremes of the range.
        ;   However, it is also influenced by the specific feature of the company (c-attribute) that produces the product, which can mitigate this range in a more or less strong manner (since it is a random -float[0;1])
        ;Quality instead doesn't depend on min and max values. It is instead calculated as a random factor * the quality level of the respective company

        let sustainability-variability ( item i p-sustainability-max-list - item i p-sustainability-min-list )
        let random-component random-float sustainability-variability
        set p-sustainability (    (item i p-sustainability-min-list) +  ( random-component * ([ c-sustainability ] of my-company ) ) )
;        print (word "p-name" p-name )
;        print (word "sustainability-variability" sustainability-variability )
;        print (word "item i p-sustainability-min-list" item i p-sustainability-min-list )
;        print (word "random-float sustainability-variability" random-component )
;        print (word "c-sustainability ] of my-company" [c-sustainability ] of my-company)
;        print (word "p-sustainability" p-sustainability)
;        print "------------------------------------------------------------------"



        set p-quality random-float 1 * [ c-quality ] of my-company

        set p-production-cost item i p-prod-cost-min-list * (1 + delta * p-sustainability-norm + omega * p-quality-norm)         ;p-price-min represents the production cost baseline

        ;Given the possible price range for each class, the attribute of new product generated, will assume a value equal to the (production cost baseline) + (a random point taken trom the attribute-varibility range)
        let price-variability ( item i p-price-max-list - p-production-cost ) * [ c-price ] of my-company
        let minimum-revenue p-production-cost * minimum-revenue-%  ;minimum-revenue espressa in euro
        let minimum-price p-production-cost + minimum-revenue
        set p-price minimum-price + ( random-float (price-variability -  minimum-revenue ))

        ;;price var= (2.6 - 1.46)* 0.73

        ;print (word "p-category: " item i p-name-list word " baseline:" item i p-prod-cost-min-list  word " price-variability: " price-variability word " p-price: " p-price)

        set p-shelf-life item i p-shelf-life-list
        set p-residual-life (item i p-shelf-life-list * p-RL-baseline) + ( (random-float (1 - p-RL-baseline) )* item i p-shelf-life-list )
        set p-RL/SL-ratio p-residual-life / p-shelf-life
        ;the logic behind SL and RL is the same used in the "new-products-creation" procedure and will be detailed in that section

        ;the hypothesis is to begin the simulation with only primary products
        set primary-prod 1
        set discounted False
        set owner-id my-id
        set p-price-norm 0
        set p-sustainability-norm 0
        set p-quality-norm 0
        set p-RL/SL-ratio-norm 0
        set p-utility 0
        set p-init-utility 0
        ;print ( word "p-name "p-name" p-price"p-price " p-sust "p-sustainability  "  p-quality  "p-quality "  )

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

  adjust-beta
  utility-function-management
  update-revenues-list

  ; 3. the product
  residual-life-consumption
  strategy-discount
  strategy-reprocess

  ; 4. the company
  sales-history-update
  demand-assessment
  new-products-creation

  company-sustainability-strategy

  ;per controllo
  if debuggino [
  check-parte-2
  ]


  tick
end

to refresh-variables
  set bought-products 0

  ask users [
    set buy-bool false
    set color grey
  ]
  set best-products-list []
  set best-companies-list []
  set users-list []
  set chosen-prod-sust-list []

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
      if (future-stock-i < 0.1)
      [
        set future-stock-i 0
      ]
      set stock replace-item i stock future-stock-i                        ;the stock is updated with the new quantity
      set i i + 1

    ]
  ]
end

;Here all the weights used in the decision-making process are normalized in view of the calculation of the utility function
;This will provide more stability to the model.
to get-normalized-status

  ;compute for each product the normalized score for price, sustainabilty, quality
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
    let min-p-RL/SL-ratio min [p-RL/SL-ratio] of products with [ p-name = my-name ]
    let max-p-RL/SL-ratio max [p-RL/SL-ratio] of products with [ p-name = my-name ]

    ;here the normalized attributes are calculated
    ifelse max-sustainability - min-sustainability != 0 [ set p-sustainability-norm (p-sustainability - min-sustainability) / (max-sustainability - min-sustainability) ] [ set p-sustainability-norm 1 ]  ;REVIEW
    ifelse max-price - min-price != 0 [ set p-price-norm (p-price - min-price) / (max-price - min-price) ] [ set p-price-norm 1 ]
    ifelse max-quality - min-quality != 0 [ set p-quality-norm (p-quality - min-quality) / (max-quality - min-quality) ] [ set p-quality-norm 1 ]
    ifelse max-p-RL/SL-ratio - min-p-RL/SL-ratio != 0 [ set p-RL/SL-ratio-norm (p-RL/SL-ratio - min-p-RL/SL-ratio) / (max-p-RL/SL-ratio - min-p-RL/SL-ratio) ] [ set p-RL/SL-ratio-norm 1 ]
  ]

end

;EXPLAIN il casino fatto con le mille liste
;la logica dietro questo pezzo di codice è che, anche se a livello logico, avrebbe senso valutare ai fini dell'acquisto solo i prodotti meno presenti nel mio stock, ai fini di comprare solo ciò che è strettamente necessario,
; nella realtà succede che un utente finisce spesso per comprare anche un prodotto che non serve.
; di conseguenza, l'approccio usato è il seguente:
; 1. prima si calcola l'utilità di tutti i prodotti
; 2. poi correggiamo questa utilità con un fattore che la smorza/amplifica in base all'effettiva necessità di quel prodotto (ovvero nella presenza o meno a stock di prodotti di quella classe)
; 3. si valuta il prodotto migliore (quello con massima utilità) e lo si acquista
; nota: questo non implica che un utente compri per forza solo i prodotti che sono necessari.
; 4. l'acquisto avviene solo

to adjust-beta

  ask users [
  let beta-corrected beta * beta-adj-factor                     ;the beta-adj-factor is 1 in the first tick. then it is incremented below for the next tick
  ;print beta-corrected

  let sum-weights alpha + beta-corrected + gamma
    set alpha-norm alpha / sum-weights
    set beta-norm beta-corrected / sum-weights
    set gamma-norm gamma / sum-weights


  set beta-adj-factor beta-adj-factor + beta-adj-factor-per-tick ;here i increase the beta-adj-factor for the next tick.
  ]

end


to utility-function-management

  ; find the best company according to each user preference
  ; first we define the weights for each user
  ask users
  [
    let my-alpha-norm alpha-norm  ;p-quality-norm weight
    let my-beta-norm beta-norm    ;p-sustainability-norm weight
    let my-gamma-norm gamma-norm  ;p-price-norm weight
    let my-epsilon epsilon        ;p-RL/SL-ratio-norm weight

    ; initialize global lists
    set utilities-list []
    set p-whos-list []

    let my-stock stock
    let my-stock-threshold u-stock-threshold
    let my-trigger trigger

    ; each user has a different threshold
    ;let my-stock-threshold p-stock-threshold


    ask products
    [
      ; first, compute the utility assuming that the quantity of stock of the class of products is not relevant (without considering the effective need)
      set p-utility (   max list ( (p-quality-norm * my-alpha-norm) + (p-sustainability-norm * my-beta-norm) - (p-price-norm * my-gamma-norm)) 0 * p-RL/SL-ratio-norm  ) ^ exponent


;      let p-utility-init (   max list ( (p-quality-norm * my-alpha-norm) + (p-sustainability-norm * my-beta-norm) - (p-price-norm * my-gamma-norm)) 0 * p-RL/SL-ratio-norm  ) ^ exponent
;      ; second, i evaluate how much stock i have for each class of products
;      let index-product position p-name p-name-list
;      ;print position p-name p-name-list
;      let i-stock item index-product my-stock
;      let i-stock-threshold item index-product my-stock-threshold
;
;
;      let stock-ratio 0
;      ifelse (i-stock-threshold = 0 )
;      [
;        set p-utility 0
;      ]
;      [
;        set p-utility p-utility-init * (my-trigger - i-stock  / i-stock-threshold)
;      ]


      ; ADJUSTMENT FACTOR - per ora non lo consideriamo
      ; se ho uno stock target/massimo, calcolo quanto mi manca ad arrivare quel limite e moltiplico quel valore per l'utilità:
      ; se mi mancano tanti prodotti della categoria i--> questo calcolo amplificherà la propensione all'acquisto per quello specifico prodotto
      ; se per una data categoria, ho lo stock che si avvicina al limite --> questo calcolo diminuirà l'utilità
      ; se ho più prodotti rispetto allo stock target,  (1 - i-stock / my-stock-threshold) sarà negativo, di conseguenza prendo il valore 0
      ; così, aggiungiamo un vincolo sui valori che può assumere l'utilità che deve essere >=0


;      ;print (word "index-product: "index-product word " my-stock: " my-stock)

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

    let chosen-product products with [who = my-best-product]; trova l'indice del prodotto venduto (nelll'ordine del file CSV)
    let index-product position ( [ p-name ] of one-of chosen-product ) p-name-list ;FB - commentare per ricordare
    let i-stock item index-product my-stock
    let i-stock-threshold item index-product u-stock-threshold
    let i-price [p-price] of one-of chosen-product
    ;let stock-ratio max list ( 1 - i-stock / i-stock-threshold ) 0
    ;let stock-ratio  1 - i-stock / stock-threshold

      let stock-ratio 0
      ifelse (i-stock-threshold = 0 )
      [
        set stock-ratio 100000
      ]
      [
        set stock-ratio (i-stock / i-stock-threshold )
      ]


      if debug [
        print ( word "tick: "ticks "who: " who " - s: " stock " - name of cp" [p-name] of chosen-product"  - st:" [u-stock-threshold] of user who " -i-stock: "precision  i-stock 2" -i-stock-threshold"precision i-stock-threshold 2 " - u:" precision utility-of-best-product 2 " t:" precision trigger 2 " |||||| left:" precision  ( stock-ratio ) 2 " <= right:" precision ( utility-of-best-product * trigger ) 2 )
        if max-utility = 0 [ print utilities-list ]
      ]


    if (stock-ratio <= (utility-of-best-product )* trigger) [
        ;in questo caso, inserendo lo stock ratio nell'equazione di acquisto, stiamo dicendo che:
        ; la mia propensione all'acquisto (ovvero il trigger)è compresa tra 0 e 2
        ; allo stesso tempo, la mancanza di prodotti nel mio stock guida la scelta del mio prodotto migliore (nel senso che, se ho bisogno di frozen food, l'utilità di quello specifico prodotto verrà incrementata)
        ; SULLA CARTA QUESTO RAGIONAMENTO DOVREBBE AVERE SENSO
        set bought-products bought-products + 1



      set buy-bool True ; the user buys an item
      set color pink
      ;print (word "tick" ticks word "who" [who] of self word " stock-ratio "(i-stock / i-stock-threshold) word "  utility-of-best-product * trigger  " (utility-of-best-product * trigger) )

      set chosen-product one-of chosen-product
      let chosen-company companies with [c-ID = [owner-ID] of chosen-product ]
        set chosen-prod-sust-list lput [p-sustainability] of chosen-product chosen-prod-sust-list      ;this list is filled in in order to make a plot
        ;print (word "---who---" [who] of chosen-product "--primary---" [primary-prod] of chosen-product"---price----"[p-price] of chosen-product "---cost---" [p-production-cost] of chosen-product "---company---" [who] of chosen-company)

        ;ora abbiamo c-memory che ha lo storico e c-new-memory = []

      set stock replace-item index-product stock ( i-stock + 1 )
      ;print (word "tick " ticks " stock-i post acquisto: " stock)
        let  my-who [who] of self

      ask chosen-company [
          ;As people buy, the following variables are updated depending on the sold products
;          set earnings earnings + [ p-price ] of chosen-product
;          set c-production-cost c-production-cost + [p-production-cost] of chosen-product
          let p-revenue [ p-price ] of chosen-product - [p-production-cost] of chosen-product
          set c-revenues c-revenues + p-revenue
          if (c-revenues <= 0)
          [
          print (word "tick" ticks " -- c-ID  " c-ID "  cum-revenues  "  precision c-revenues 2 " p-disc% " [p-discount] of chosen-product" discounted " [discounted ] of chosen-product"  p-price  " precision [p-price] of chosen-product 2  "  p-prod-cost  " precision [p-production-cost] of chosen-product 2 "  class  "[p-name]  of chosen-product"  who  " [who]  of  chosen-product  "  primario?  " [primary-prod ]of chosen-product  " acquirente " my-who  " c-price "c-price)
          ]

        ; add the memory in the correct position
        let c-new-memory-to-add item index-product c-new-memory ; prendo l'elemento da aumentare di uno dalla memoria temporanea
        set c-new-memory-to-add c-new-memory-to-add + 1 ; lo aumento di 1 perché ho venduto 1
        set c-new-memory replace-item index-product c-new-memory c-new-memory-to-add ; sostituisco con il valore da cui l'ho preso

      ]

        ;print (word "c-ID: " [owner-id] of chosen-product " - c-sust: " [c-sustainability] of chosen-company " - c-price: " [c-price] of chosen-company " - p-name: " [p-name] of chosen-product " - p-price: " [p-price] of chosen-product)

      ask chosen-product [ die ]
    ]
      ;print (word "tick: " ticks " who" [who] of self " i "index-product " stock-ratio: "precision (i-stock / i-stock-threshold) 2 " i-stock: " precision i-stock  2 " i-stock-threshold: " precision i-stock-threshold 2 "  result ut*trig " precision (utility-of-best-product * trigger) 2 "  utility-of-best-product " (precision utility-of-best-product 2) "  trigger: "trigger " buy-bool "buy-bool )
    ]
  ]

end

to update-revenues-list
  ask companies [
    ;The following lists are updated based on the output results of the procedure utility-function-management
    set c-revenues-list lput c-revenues c-revenues-list

    ;Reset the following variable for the next tick
    set earnings 0
    set c-production-cost 0
    set c-revenues 0
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
    if p-residual-life = 0 [
     set died-products died-products + 1
      die ]
  ]
end

;;;;SHORT TERM STRATEGIES
;Before letting a product die and thereby making it a waste, a company can adopt strategies to incentivize its sale.
;The first is to reduce the product price, while the second will act on the second attribute (product sustainability).
;These strategies will be applied once the product reaches 2 thresholds positioned in its useful life

to strategy-discount
  ask products with [ p-residual-life <= (threshold-1 * p-shelf-life) and discounted = False]
  [
    set p-price max list (p-discount * p-price) (p-production-cost)
    set discounted True
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
    let eligible-products products with [p-name = p-name-to-be-transformed and p-residual-life <= (threshold-2 * p-shelf-life) and primary-prod = 1]
    ;print( word "eligible-products" count eligible-products )
    ;print (word "numero agenti totali: " count products)

    ;here only the products that satisfy the RL criteria, will be reprocessed

    if any? eligible-products
      [
        ;print (word "numero agenti da riprocessare: " count products word " RL:  " mean [p-residual-life] of products word " t2* SL: " threshold-2 * (mean [p-shelf-life] of products) )

        set j j + 1
        let n-products-to-transform count eligible-products
        ;first, the waste generated is managed
        let p-waste item j item i m1
        ;print(word "tick--" ticks"--class--" p-name-to-be-transformed"--p-waste--" p-waste "--i--"i "--j--"j )

        ;print ( word "n-class-of-products-to-transform" n-class-of-products-to-transform )



        if (p-waste > 0)
        [
          let n-products-to-waste ceiling (n-products-to-transform * p-waste) ;the number of products to waste, is rounded up to an integer number
          ;print (word "n-products-to-waste" n-products-to-waste )
          set wasted-prod n-products-to-waste
          set wasted-prod-cum wasted-prod-cum + wasted-prod

          ask n-of n-products-to-waste eligible-products [die]
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
            ;print (word "n-products-to-reprocess" n-products-to-reprocess )

            ask n-of n-products-to-reprocess eligible-products
            [
              let current-product self

            hatch 1
            [
                let old-price p-price
                ;if owner-id = 1 [print (word "who prodotto riprocessato" [who] of self)]
              ;Setup the attributes of the reprocessed product (k)
                ask current-product [die]
                let p-name-k (item j item 0 m1)
                let my-owner-id [owner-id] of self
                set primary-prod 0
                set discounted False
                let k position p-name-k p-name-list
                let matching-products products with [p-name = p-name-k and owner-id = my-owner-id and primary-prod = 1]
                ifelse (count matching-products != 0)
                [
                  let sustainability-max-k  (max [p-sustainability] of matching-products) * beta-adj-factor
                  set p-sustainability min (list  ((p-sust-increase * sust-increase-adj-factor) * sustainability-max-k )  1)       ;
                ]
                ;else
                [
                  let sustainability-max-k (item k p-sustainability-max-list)
                  ;set p-sustainability min (list  (p-sust-increase * sustainability-max-k )  1)


                  set p-sustainability min (list  (p-sust-increase * sustainability-max-k * sust-increase-adj-factor)  1)
                  set sust-increase-adj-factor sust-increase-adj-factor + sust-increase-adj-factor-per-tick
                ]
                set p-quality p-quality * p-quality-decrease
                set p-name p-name-k  ;p-name of the reprocessed product: must be set after the evaluation of sustainability-max-k


;                print (word "Matching products count: " count matching-products)
;                print ([p-sustainability] of matching-products)

                ;print (word "my-owner-id"my-owner-id)
              ;print (word "p-name-k: " p-name-k word " item: " position p-name-k p-name-list)


              ;sustainability of reprocessed products is always increased with respect to the destination class, as the reprocessing extends the shelf life and therefore reduces the probability of becoming waste
              ;reprocessed products are perceived as more sustainable than primary products of the same class, as they are generated from material that would have become waste.
              ;let sustainability-min-k item k p-sustainability-min-list
              ;let sustainability-max-k item k p-sustainability-max-list
               ;let sustainability-min-k min ([p-sustainability] of products with [p-name = p-name-k and owner-id = my-owner-id])


               ; print sustainability-max-k
                ;print (word "sust max "sustainability-max-k " c-ID " my-owner-id " p-sust-increase "p-sust-increase)
                ;let mean-sustainability-k (sustainability-min-k + sustainability-max-k) / 2
                ;set p-sustainability p-sust-increase * sustainability-max-k


              ;once identified the name of the destination class of the reprocessing, the corresponding attributes (price, sust...etc) are retrieved
              ;price and residual life of reprocessed products are set as mean values of the destination class.

                ;first i normalize the sustainability score
                let max-sustainability max [ p-sustainability ] of products with [ p-name = p-name-k ]
                let min-sustainability min [ p-sustainability ] of products with [ p-name = p-name-k ]
                let max-quality max [ p-quality ] of products with [ p-name = p-name-k ]
                let min-quality min [ p-quality ] of products with [ p-name = p-name-k ]
                ifelse max-sustainability - min-sustainability != 0 [ set p-sustainability-norm (p-sustainability - min-sustainability) / (max-sustainability - min-sustainability) ] [ set p-sustainability-norm 1 ]
                ifelse max-quality - min-quality != 0 [ set p-quality-norm (p-quality - min-quality) / (max-quality - min-quality) ] [ set p-quality-norm 1 ]

              set p-production-cost item k p-prod-cost-min-list * (1 + delta * p-sustainability-norm + omega * p-quality-norm)
              let price-max-k item k p-price-max-list
              let mean-price-k (p-production-cost + price-max-k) / 2
              set p-price mean-price-k
              set p-residual-life (item k p-shelf-life-list * p-RL-baseline) + ( (random-float (1 - p-RL-baseline) )* item k p-shelf-life-list )
              ; here the assumption is that the reprocessed product will have an average residual-life in line with the new class of products to which it belongs

              set p-shelf-life item k p-shelf-life-list


                ifelse (old-price = p-price)
                [print "same value reprocess"]
                [ifelse (old-price > p-price)
                  [print "lower value reprocess" ]
                  [print "higher value reprocess"]
                ]
            ]


            ]

          ]
        ]

    ]
    set j 0
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
    let weights-list [0.15 0.14 0.13 0.12 0.11 0.10 0.09 0.07 0.05 0.04]
    while [i < n-class-of-products]
    [
      let n-product-sold-class-i 0
      let k 0
      while [ k < c-len-memory]
      [
        set n-product-sold-class-i (item k weights-list) * (item i item k c-memory) + n-product-sold-class-i
        set k k + 1
      ]
      set n-product-sold-class-i ceiling ( n-product-sold-class-i * 1)   ;;;fix review: possiamo provare a risettarlo a 1.10/1.15/1.2 in modo da dare produrre più prodotti
      set c-demand replace-item i c-demand n-product-sold-class-i
      set i i + 1
    ]
    set tot-demand [sum c-demand] of self
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
        fd 3
        set primary-prod 1
        set discounted False

        set p-name item j p-name-list
        let sustainability-min-j max (list ([p-sustainability] of products with [p-name = item j p-name-list and owner-id = my-id and primary-prod = 1]) item j p-sustainability-min-list)
        ; prende il valore più alto di sostenibilità tra quella dei prodotti in circolo e quella dalla lista importata dal csv (se non ci sono prodotti in circolo, la p-sust dei prodotti sarebbe  0, quindi prenderebbe il valore del csv)
        let sustainability-max-j max (list ([p-sustainability] of products with [p-name = item j p-name-list and owner-id = my-id and primary-prod = 1]) item j p-sustainability-max-list)

        let sustainability-variability ( sustainability-max-j - sustainability-min-j )
        let random-component (random-float sustainability-variability )

        set p-sustainability sustainability-min-j + (random-component * ([ c-sustainability ] of my-company ) )

        set p-production-cost item j p-prod-cost-min-list * (1 + delta * p-sustainability-norm + omega * p-quality-norm)
        let price-variability ( item j p-price-max-list - p-production-cost ) * [ c-price ] of my-company
        let minimum-revenue p-production-cost * minimum-revenue-%  ;minimum-revenue espressa in euro
        let minimum-price p-production-cost + minimum-revenue
        set p-price minimum-price + ( random-float (price-variability -  minimum-revenue ))





        ;p-shelf-life is assumed as the same for all products of the same class
        ;p-residual-life represents the remaining life of the product at the time it arrives at the shop. It is therefore heterogeneous as it takes into account all those real factors that may cause
        ;the product to arrive at the shop at a different time with respect to the moment it is actually produced (e.g. lead time, responsiveness of the company... etc).
        ;In order for the product to remain competitive, not too much time must pass from the moment it is produced and when it reaches the shop.
        ;Consequently the minimum limit for RL is set at 80% of the SL (and the maximum will be 100% of the SL)
        set p-shelf-life item j p-shelf-life-list
        set p-residual-life (item j p-shelf-life-list * p-RL-baseline) + ( (random-float (1 - p-RL-baseline) )* item j p-shelf-life-list )
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
to company-sustainability-strategy
;solo strategia di sostenibilità:


  ;se per x periodi ho le revenues < rispetto a quanto mi aspetto,  allora incremento c-sustainability

let condition-met? all? companies [
    length c-revenues-list = length-revenues-list
    ; c-revenues-list is updated at each tick. So, if the c-revenues-list has reached lenght = length-revenues-list (f.e. 1 year), it means that it's time to evaluate the strategy activation
  ]

  if (condition-met?)[

      ;allora valutiamo se  applicare la strategia di sostenibilità

    ;here all companies will insert their own revenues so that they are public and visible to everyone, so that companies will be able to choose the strategy also considering their competitors
  ask companies [
      set g-total-revenues-list lput (sum c-revenues-list) g-total-revenues-list
      ;global variable which is a list containing a number of item = n-companies. each item is = mean-revenue-per-product
  ]
    ;Here the global list "g-total-revenues-list" is completed

      let max-revenues max g-total-revenues-list

    ask companies [
      let my-total-revenues sum c-revenues-list                      ;these are the total  revenues of the semester/year/...etc
      set my-target-revenues my-total-revenues + random-float (max-revenues - my-total-revenues) * (my-total-revenues / max-revenues)
      let last-three sublist c-sust-strategy-memory (length c-sust-strategy-memory - c-strategy-frequency) (length c-sust-strategy-memory) ;here the last three elements of the list are extracted to be later evaluated:
                                                                                                                        ;f.e. if there is one element = 1, it means that the strategy has been applied once
                                                                                                                        ;in the latest 3 years / semesters /...etc

      ifelse ( my-total-revenues < my-target-revenues and sum last-three = 0)
      [
        set c-sustainability min (list (c-sustainability * c-sust-increase) 1)
        set c-sust-strategy-memory lput 1 c-sust-strategy-memory     ;the c-sust-strategy-memory list is filled in every (length-revenues-list) ticks.
      ]
      ;else
      [
        set c-sust-strategy-memory lput 0 c-sust-strategy-memory
      ]

      set c-revenues-list []

      ]

      ];fine if

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

to check-parte-2


;let i 0
;while [i < length p-name-list] [
;  ; Ottieni il nome del prodotto corrente
;  let current-product-name item i p-name-list
;
;  ; Crea un agentset di tutti i prodotti con il nome corrente e primary-prod = 1
;  let products-with-name products with [p-name = current-product-name and primary-prod = 0]
;
;  ; Conta quanti sono i prodotti in questa classe
;  let count-products count products-with-name
;
;    if (count-products != 0) [
;
;  ; Calcola la media di p-sustainability per questa classe
;  let avg-p-sustainability precision mean [p-sustainability] of products-with-name 2
;
;  ; Stampa i risultati
;  print (word "Prodotto: " current-product-name ", Numero: " count-products ", Media di p-sustainability: " avg-p-sustainability)
;    ]
;
;  ; Incrementa l'indice
;  set i i + 1
;]
   print ( word  "company-1 " [c-sustainability] of companies with [c-ID = 1])
  ask products  with [owner-id = 1][
  print (word "who--" who "--p-sustainability-- " precision p-sustainability 3 "--p-name--" p-name "--primary-prod --"primary-prod )
  ]

    print ( word  "company-2 " [c-sustainability] of companies with [c-ID = 2])
  ask products  with [owner-id = 2][
  print (word "p-sustainability-- " precision p-sustainability 3 "--p-name--" p-name "--primary-prod --"primary-prod )
    ]

      print ( word  "company-3 " [c-sustainability] of companies with [c-ID = 3])
  ask products  with [owner-id = 3][
  print (word "p-sustainability-- " precision p-sustainability 3 "--p-name--" p-name "--primary-prod --"primary-prod )
      ]

        print "-----------------------------------------------------------------"






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
12
79
184
112
n-companies
n-companies
1
20
3.0
1
1
agents
HORIZONTAL

SLIDER
11
114
185
147
n-users
n-users
10
50
50.0
5
1
agents
HORIZONTAL

MONITOR
382
357
555
418
Mean price
precision mean ( [p-price] of products ) 2
17
1
15

MONITOR
385
422
556
483
Mean sustainability
precision mean [ p-sustainability ] of products  2
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
636
591
885
747
User stock of products
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [ mean stock ] of users"

SWITCH
12
157
115
190
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

MONITOR
92
536
284
597
TOT number of products
count products
15
1
15

PLOT
634
404
1226
563
N-products reprocessed vs normal
NIL
NIL
0.0
1.0
0.0
10.0
true
true
"" ""
PENS
"tot-n-of-products" 1.0 0 -1184463 true "" "plot count products"
"n-primary-products" 1.0 0 -2674135 true "" "plot count products with [primary-prod = 1]"
"n-reprocessed-products" 1.0 0 -14439633 true "" "plot count products with [primary-prod = 0]"

SLIDER
12
205
184
238
trigger-max
trigger-max
0
2
2.0
0.1
1
NIL
HORIZONTAL

MONITOR
383
487
555
556
wasted-prod 
wasted-prod
17
1
17

PLOT
1231
405
1480
559
wasted-products
NIL
NIL
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -955883 true "" "plot wasted-prod "
"pen-1" 1.0 0 -7500403 true "" "plot died-products"

PLOT
1231
18
1483
225
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
3
346
176
391
Products Class 1 (Fruits & Veg)
count products with [p-name = item 0 p-name-list]
17
1
11

MONITOR
3
393
177
438
Products Class 2 (Frozen Food)
count products with [p-name = item 1 p-name-list]
17
1
11

MONITOR
2
441
176
486
Products Class 3 (Sweets)
count products with [p-name = item 2 p-name-list]
17
1
11

MONITOR
0
489
177
534
Products Class 4 (Canned Food)
count products with [p-name = item 3 p-name-list]
17
1
11

MONITOR
182
347
339
392
Products Class 5 (Meat)
count products with [p-name = item 4 p-name-list]
17
1
11

MONITOR
184
396
339
441
Products Class 6 (Fish)
count products with [p-name = item 5 p-name-list]
17
1
11

MONITOR
183
443
340
488
Products Class 7 (Pasta)
count products with [p-name = item 6 p-name-list]
17
1
11

SLIDER
14
248
186
281
target-baseline
target-baseline
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
631
239
1104
399
Company vs product sustainability
NIL
NIL
0.0
1.0
0.0
0.1
true
true
"" ""
PENS
"avg-prod-sust" 1.0 0 -1184463 true "" "plot mean [p-sustainability] of products "
"c-sustainability" 1.0 0 -11033397 true "" "plot mean [c-sustainability] of companies"
"reprocessed-prod-sust" 1.0 2 -14439633 true "" "ifelse (any? products with [primary-prod = 0])\n[ plot mean [p-sustainability] of (products with [primary-prod = 0]) ]\n[ plot 0 ]"
"primary-prod-sust" 1.0 0 -2674135 true "" "if (any? products with [primary-prod = 1]) [\nplot mean [p-sustainability] of (products with [primary-prod = 1])]"

SWITCH
125
157
233
190
debuggino
debuggino
1
1
-1000

SLIDER
11
290
183
323
limit-cons-per-user
limit-cons-per-user
0
1
0.9
0.1
1
NIL
HORIZONTAL

PLOT
1228
236
1482
399
Average sustainability weight normalized
NIL
NIL
0.0
1.0
0.0
0.5
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [beta-norm] of users"

PLOT
632
16
1104
235
Purchases vs Product-sustainability
NIL
NIL
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"purchases" 1.0 0 -16777216 true "" "plot (bought-products ) / n-users"
"avg-product-sust" 1.0 0 -1184463 true "" "plot mean [p-sustainability] of products"
"reprocessed-prod-sust" 1.0 2 -14439633 true "" "ifelse (any? products with [primary-prod = 0])\n[ plot mean [p-sustainability] of (products with [primary-prod = 0]) ]\n[ plot 0 ]"

@#$#@#$#@
---------------------------------------------------------
## Problemi da risolvere

#### problemi  minori

- impostare vincoli t.c.  se qualcosa  nella simulazione non ha senso, allora venga  stoppata (f.e.: vedi if count  products !=0)

- cercare di sistemare il modo in cui viene settata p-sustainability perché ora non riesce a vedersi l'incremento di sustainability quando quando aumenta la
	- c-sustainability
	- numero riprocessati
- capire valore ottimale di esponente per p-utility


## NOTA BENE
- nota: netlogo è case sensitive, quindi può essere necessario implementare un check sul nome dei prodotti inseriti nella matrice
- in strategy-reprocessing: per chiamare l'elemento i,j devo scrivere "item j item i m1"

## NOTE PER LA TESI
- vanno bene le SS per come sono impostate ora: giustificarle poi in tesi
--> va bene tenerle ma bisogna giustificarle bene altrimenti sembra un escamotage per far quadrare i conti: 
in caso di simulazioni con basse numerosità (pochi users e poche companies), se un utente in un tick non compra per cause aleatorie, la domanda media diminuisce di una quantità non trascurabile perchè 1 singolo utente ha un peso maggiore in questo caso rispetto al peso che avrebbe in modello con 100 utenti. 
--> per evitare che con basse numerosità, un mancato acquisto generi instabilità, vengono inserite le SS per smorzare e filtrare il bullwhip effect.
Senza le SS, un mancato acquisto, diminuirebbe la domanda media, e quindi lo storico, quindi la produzione e, se le companies non producono, gli utenti non posso comprare e l'effetto continua ad essere amplificato fino a quando ci si allontana troppo dal punto di equilibrio e stabilità. 
- p-sustainability: per fashion rappresenta emissioni per singolo uso--> con l'usato, allungo la vita--> riduco emissioni per consumo
- p-sustainability: per food rapprenta emissioni legate alla produzione e smaltimento. di conseguenza con il riprocessamento, bypasso lo smaltimento ed, evitanto emissioni aggiuntive per lo smaltimento, incrementiamo la sostenibilità
- quality: per fashion si intende durevolezza. poi dipenderà dal singolo utente e dal peso che viene dato a questo fattore, se la qualità sarà impattante sulla decisione di acquisto
- quality: per food si intende quanto è sano (es: nutriscore). poi dipenderà dal singolo utente e dal peso che viene dato a questo fattore, se la qualità sarà impattante sulla decisione di acquisto
- 
- nel settare i valori della matrice, tenere in considerazione che il p-price-min è in realtà il costo di produzione minimo (--> potrà valere meno di p-sustainability *(1-30%))
- p-residual-life di prodotto riprocessato nel food
- p-residual-life di prodotto riprocessato nel fashion
- nel  nostro modello l'effetto rebound  si misura in termini di frequenza di acquisto  e non di quantità  acquistate: infatti può capitare che gli utenti comprino anche quando non necessario grazie al trigger 
- valutare se introdurre il vincolo minimo sulla (u-stock-threshold) per determinate classi di prodotti oppure spiegare che è una limitazione del modello
- NB nel momento in cui si settano le threshold nell'excel (che verranno importate con stock-threshold-list), avrebbe senso settarle  in modo t.c. siano più o meno proporzionali ai tassi di consumo per la stessa categoria (cons-per-user).




## IPOTESI MODELLISTICHE
- idealmente il "consumo" dello stock degli utenti e la riduzione della RL dei prodotti a scaffale nei negozi, dovrebbero avvenire contemporaneamente (o prima o dopo l'azione di acquisto). Nel modello avvengono in modo disallineato per una maggiore semplicità e schematicità delle procedure del codice
- la p-utility può assumere valori compresi tra 0 e 1 (estremi inclusi): il limite inferiore è zero in quanto è necessario che l'utilità sia maggiore di 0 per poterla elevare all'esponente 

### users
- il trigger è la preferenza di acquisto per ciascun utente generale. Gli utenti hanno trigger eterogenei compresi tra 0 e 2 (settato tramite uno slider)
- la stock-threshold è un attributo tipico di ogni utente (u-stock-threshold): per ogni utente viene creata randomicamente una lista che per ogni classe di prodotto prende un valore compreso tra 0 e la p-stock-threshold di quella classe settata nel csv
- cons-per-user rappresenta i tassi di consumo per ogni classe di prodotto: la loro somma non deve essere troppo bassa (altrimenti gli user non consumano) ma nemmeno troppo alta (altrimenti, comprano esattamente ciò che consumano e non c'è margine per il rebound, soprattutto considerando il vincolo di 1 solo acquisto per tick)--> ora il limite massimo sulla loro somma è settato tramite uno slider. PEr ora i dati che mostrano meglio un andamento dinamico (ma che non genera rebound) sono quelli importati dal csv (con somma = 0.95)
- un utente compra solo un prodotto per ciascun turno, indipendentemente dalle quantità (è un modello teorico, ma vi dovete laurerare)
- i pesi alpha, beta e gamma con i quali l'utente pesa i vari attributi nel calcolo della funzione di utilità, sono normalizzati in modo tale che la loro somma sia = 1 (peso / somma di tutti i pesi)
- ipotizziamo che, con il passare del tempo, il peso medio che l'utente dà alla sostenibilità di un prodotto (beta e beta-norm) aumenti lentamente (prevedendo un incremento per ogni tick inversamente proporzionale al numero di tick della simulazione considerata: beta-adj-factor e beta-adj-factor-per-tick)



### products
- ogni agente prodotto rappresenta un "batch di prodotto" ed è una quantità comprabile da un utente: in questo modo rende concettualmente realistico il fatto che l'utente possa fare pochi acquisti a settimana. Ogni batch di prodotto vale un'unica unità
- quindi, ciascun prodotto ha una classe specificia di appartenenza (p-name) che rappresenta la sua categoria (Fruits and vegetables, canned food, ... oppure t-shirt, pantaloni, ...)
- la normalizzazione va fatta solo tra prodotti della stessa classe (non posso normalizzare il prezzo di una mela con il prezzo della carne): vengono normalizzati tutti gli attributi (p-quality, p-sustainability, p-price, p-RL/SL-ratio)
- la shelf life è uguale per tutti i prodotti della stessa classe, le aziende non competono su ciò (la pasta di diverse compagnie ha durata uguale oppure la durata delle stagioni nel fashion è uguale a parità di classe di prodotti)
- il reprocessesing avviene solo con RL compresa tra 0 e soglia di threshold-2 * shelf life


- la produzione delle aziende è fatta in modo che producano la domanda di ciascun prodotto meno le il numero di prodotti per ciascuna classe, che ogni azienda già possiede.
- la simulazione inizia con solo prodotti primari
- il reprocessing può avvenire solo per prodotti primari (= un prodotto non può essere riprocessato più di una volta)
- ogni prodotto generato può essere scontato una sola volta ma un prodotto riprocessato può essere di nuovo scontato nella "nuova vita" 
- Gli attributi come qualità, sostenibilità dei prodotti nuovi generati sono calcolati nel seguente modo: baseline + componente randomica che è influenzata anche dal corrispettivo attributo della compagnia (vedi formule)
- per quanto riguarda il prezzo: prima viene settato il costo di produzione che dipenderà da una baseline (costo minimo o p-prod-cost-min-list) + una componente aggiuntiva che sarà proporzionale al livello di sostenibiltà e qualità del prodotto
- il costo di produzione rappresenta la baseline per il prezzo (p-price) 
- il prezzo è calcolato come baseline + una componente randomica che tenga conto delle revenue minime (settate al 20% del p-production cost)
- in fase di normalizzazione delle variabili usate per calcolare l'utilità, se il valore min e il valore max sono uguali, allora settiamo il valore normalizzato a 1

- nel reprocessing, un'unità intera di prodotto di partenza dà vita ad un'unità intera di prodotto riprocessato
- date x unità di prodotti candidati al riprocessamento, solo la percentuale indicata nella matrice m1, verrà effettivamente riprocessata. Le restanti unità diventano waste
- nel momento in cui un prodotto viene generato/riprocessato, la sua residual life nel momento in cui diventa disponibile per la vendita, viene settata un modo randomico ma compresa tra l'80% e il 100% della shelf life
- come cambia quality una volta che riprocessiamo:
	- HP: nel food-> diminuisce sempre perche aggiungo additivi
	- HP: nel fashion-> diminuisce sempre perché < durevolezza
- nel reprocessing, la sustainability viene incrementata del 10% rispetto al prodotto primario della stessa classe e con sostenibilità maggiore


### companies
- la domanda prevista nel setup dalle aziende per ciascun prodotto è: il prodotto fra il consumo pro-capite di ciascun prodotto per tick (cons-per-user) e il numero di utenti. 
- le aziende all'inizio hanno uno stock pari a n-utenti * consumo / n-aziende, quindi la propria quota iniziale fittizia
- le aziende hanno una memoria di lunghezza fissa (la lista che funge da storico acquisti, considera lo stesso numero di periodi)
- la memoria iniziale delle aziende riguardo alla domanda passata è n-utenti * consumo / n-aziende
- le aziende hanno capacità produttiva infinita, di conseguenza la domanda può essere settata senza nessun vincolo
- ogni compagnia ha delle scorte di sicurezza: esse sono omogenee tra tutte le compagnie e direttamente proporzionali ai tassi di consumo: 10 * cons-per-user.
- la domanda prevista dalle compagnie si assume in linea con gli acquisti medi degi ultimi 10 periodi ma dando un maggiore peso alla domanda dei periodi più recenti: la domanda è calcolata come una media pesata secondo i pesi assegnati in "weights-list".
- le compagnie aggiornano le loro revenues (c-revenues) durante il tick ( durante la giornata/mese). A fine tick questi risultati vengono  aggiunti in una lista (c-revenues-list) che contiene tanti eleventi quanto length-revenues-list: questa lista può essere quindi considerata un "bilancio" di quel numero di tick.
-  Ogni (length-revenues-list) tick si valuta se applicare la strategia di sostenibilità: le compagnie consultano il bilancio e valutano se è necessario implementare la strategia per incrementare la c-sustainability nel lungo termine. Ci si aspetta che, a cascata anche la p-sustainability (e infine anche le vendite) vengano influenzate da questo incremento.
- abbiamo implementato una memoria per limitare la frequenza di applicazione di c-sustainability-strategy (altrimenti sarebbe risultato che le companies non prime per revenues applicavano praticamente sempre la strategia)
- parallelamente e in risposta all'incremento di beta (beta-adj), le compagnie iniziano a  riprocessare i prodotti e ottimizzano il processo di riprocessamento  sempre di più, in modo linearmente crescente e graduale (l'ottimizzazione migliora ulteriormente, in aggiunta a p-sust-increase, la sostenibilità del prodotto riprocessato di un fattore moltiplicatore crescente ma molto piccolo = sust-increase-adj-factor)
es: se sust-increase-adj-factor-per-tick = 0.00001 e a parità di tutte le altre condizioni,
se ipotizzando  che lunedì riprocessiamo un prodotto con sostenibilità-post riprocessamento= 0.2,
riprocessare lo stesso prodotto 7gg dopo, ci porterà ad ottenere un prodotto di p-sustainability= 0.2 + 0.00007


## COSE DA SETTARE DIVERSAMENTE TRA I DUE SETTORI
- il reprocessing avviene una volta superata una certa soglia: per il food è i 2/3; per il fashion è 0/ più bassa (se tenere una threshold != 0 e una =0 non è un problema a livello concettuale, sarebbe la soluzione più coerente con la realtà; tuttavia tenerle entrambe != 0 sarebbe più elegante)
- 1 tick è valido 1  giorno nel settore food VS 2 settimane/1 mese nel settore fashion
- length-revenues-list ipotizziamo rapprenti un anno-> il numero di tick corrispondenti dipende dal contesto
- cambiano le matrici, soglie...etc
- beta-adj-factor-per-tick e sust-increase-adj-factor-per-tick (il secondo dipende dal primo in automatico)



## LIMITAZIONI DEL MODELLO:
- un utente compra solo un prodotto per ciascun turno: molto limitante
- reprocessing, un'unità intera di prodotto di partenza dà vita ad un'unità intera di prodotto riprocessato: nella realtà non esiste un'esatta corrispondenza 1:1
- Non viene considerato il costo di smaltimento e il costo di riprocessamento
- il modello fa emergere la correlazione tra l'esistenza di prodotti riprocessati (più sostenibili dei primary della stessa classe) e aumento di acquisti. Questo è già un risultato importante anche se per dimostrare la diretta causalità trai due fattori, sarebbe opportuno sviluppare un modello ancora più realistico, togliendo il vincolo che prevede che un user possa acquistare 1 solo prodotto per ogni tick. Così facendo, si riuscirebbe a dimostrare meglio come, alcuni acquisti siano guidati da un'effettiva necessità, mentre altri dettati da comportamenti consumisti (ovvero si compra più del necessario) e questi ultimi si verificano in  presenza di prodotti più sostenibili.
- l'incremento di sostenibilità dovuto al riprocessamento è ora un parametro globale che quindi non dipende dal tipo di riprocessamento eseguito. Nella realtà, tipi di riprocessamento diversi hanno impatti diversi in termini di emissioni, di conseguenza p-sust-increase dovrebbe essere eterogeneo tra le diverse classi di prodotto.
- la company con revenues più alte nel periodo considerato per la valutazione dell'applicazione della strategia di sostenibilità, per definizione non può attivare la strategia in quel momento. Tuttavia la best-in-class può cambiare nei diversi periodi di valutazione.



## DA VALUTARE:
- introdotto un adjustement factor che va a sostituire questa parte: 
old: p-utility p-init-utility * ( 1 - i-stock/i-stock-threshold )
new: p-utility p-init-utility * ( adjustment-factor )
- quality min e max tolta da csv



## COSA SIGNIFICANO LE VARIABILI

- p-residual-life rappresenta la vita residua  del prodotto nel momento in cui quest'ultimo arriva in negozio. di conseguenza è eterogenea in quanto tiene conto di tutti quei fattori reali che possono causare l'arrivo del prodotto a negozio in un momento diverso da quando viene effettivamente manufactured (es: lead time, responsiveness of the company...etc).
Per fare in modo che il prodotto rimanga competitivo, non deve passare troppo tempo da quando viene manufactured a quando raggiunge il negozio. di conseguenza il limite minimo per la RL viene settato all'80% della SL (e il massimo sarà il 100% della SL)
Abbiamo ipotizzato che, senza questo  "stratagemma" RL/SL sarebbe stato un rapporto meno eterogeneo
- p-sustainability= inversamente proporzionale alle emissioni associate a quel prodotto dove le emissioni dipendono sia dalle materie prime utilizzate che dal processo produttivo impiegato--> se in  un prodotto il processo produttivo del prodotto in se e delle materie prime usate, emette tanta CO2, allora avrà p-sustainability più bassa.















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
<experiments>
  <experiment name="prova FB" repetitions="2" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>mean [ c-price ] of companies</metric>
    <metric>mean [ c-sustainability ] of companies</metric>
    <metric>mean [ c-quality ] of companies</metric>
    <metric>counter-sales</metric>
    <enumeratedValueSet variable="n-companies">
      <value value="2"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="debug">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-users">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trigger-baseline">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
