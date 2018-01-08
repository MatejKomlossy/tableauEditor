module Zipper exposing (..)

--crumb hovori o tom, kto je podo mnou


type alias Ref =
    { str : String, up : Maybe Int }


defRef =
    { str = "", up = Nothing }


type alias Node =
    { id : Int, value : String, reference : Ref }


defNode =
    { id = 1, value = "", reference = defRef }


type alias Tableau =
    { node : Node, ext : Extension }


type Extension
    = Open
    | Closed Ref Ref
    | Alpha Tableau
    | Beta Tableau Tableau



--
-- view helpers - convert to table
--


type alias CellWidth =
    Int


type alias Cell =
    ( CellWidth, Maybe Zipper )



-- the 'Node' at that point


type alias Row =
    List Cell


type alias Table =
    List Row


asTable : Tableau -> Table
asTable t =
    let
        z =
            zipper t

        ( c, tbl ) =
            asHeadedTable z
    in
        [ [ c ] ] ++ tbl


asHeadedTable : Zipper -> ( Cell, Table )
asHeadedTable ( t, bs ) =
    case t.ext of
        Open ->
            ( ( 1, Just ( t, bs ) ), [] )

        Closed _ _ ->
            ( ( 1, Just ( t, bs ) ), [] )

        Alpha tableau ->
            let
                sz =
                    ( t, bs ) |> down

                ( top, table ) =
                    asHeadedTable sz

                ( topWidth, topElem ) =
                    top
            in
                ( ( topWidth, Just ( t, bs ) ), [ [ top ] ] ++ table )

        Beta ltableau rtableau ->
            let
                lz =
                    ( t, bs ) |> left

                rz =
                    ( t, bs ) |> right

                ( ltop, ltable ) =
                    asHeadedTable lz

                ( ltopWidth, ltopE ) =
                    ltop

                ( rtop, rtable ) =
                    asHeadedTable rz

                ( rtopWidth, rtopE ) =
                    rtop
            in
                ( ( ltopWidth + rtopWidth, Just ( t, bs ) )
                , [ [ ltop, rtop ] ] ++ (merge ltable rtable)
                )



-- grr, no asymetric map2 ;(


merge : List (List a) -> List (List a) -> List (List a)
merge ll rl =
    case ( ll, rl ) of
        ( lh :: lt, rh :: rt ) ->
            (lh ++ rh) :: merge lt rt

        ( [], rh :: rt ) ->
            rh :: merge [] rt

        ( lh :: lt, [] ) ->
            lh :: merge lt []

        ( [], [] ) ->
            []



--ZIPPER


type Crumb
    = AlphaCrumb Node
    | BetaLeftCrumb Node Tableau
    | BetaRightCrumb Node Tableau


type alias BreadCrumbs =
    List Crumb


type alias Zipper =
    ( Tableau, BreadCrumbs )


zipper : Tableau -> Zipper
zipper t =
    ( t, [] )


children : Zipper -> List Zipper
children z =
    let
        ( t, bs ) =
            z
    in
        case t.ext of
            Open ->
                []

            Closed _ _ ->
                []

            Alpha _ ->
                [ down z ]

            Beta _ _ ->
                [ left z, right z ]


down : Zipper -> Zipper
down ( t, bs ) =
    case t.ext of
        Alpha t ->
            ( t, (AlphaCrumb t.node) :: bs )

        _ ->
            ( t, bs )


right : Zipper -> Zipper
right ( t, bs ) =
    case t.ext of
        Beta tl tr ->
            ( tr, (BetaRightCrumb t.node tl) :: bs )

        _ ->
            ( t, bs )



--vracia zipper pre mojho laveho syna


left : Zipper -> Zipper
left ( t, bs ) =
    case t.ext of
        Beta tl tr ->
            ( tl, (BetaLeftCrumb t.node tr) :: bs )

        _ ->
            ( t, bs )


up : Zipper -> Zipper
up ( t, bs ) =
    case bs of
        (AlphaCrumb n) :: bss ->
            ( Tableau n (Alpha t), bss )

        (BetaLeftCrumb n tr) :: bss ->
            ( Tableau n (Beta t tr), bss )

        (BetaRightCrumb n tl) :: bss ->
            ( Tableau n (Beta tl t), bss )

        [] ->
            ( t, bs )


top : Zipper -> Zipper
top ( t, bs ) =
    case bs of
        [] ->
            ( t, bs )

        _ ->
            top (up ( t, bs ))


above : Int -> Zipper -> Zipper
above n z =
    case n of
        0 ->
            z

        n ->
            above (n - 1) (up z)



--helpers


modifyNode : (Tableau -> Tableau) -> Zipper -> Zipper
modifyNode f ( tableau, bs ) =
    ( f tableau, bs )


zTableau : Zipper -> Tableau
zTableau ( t, bs ) =
    t


zNode : Zipper -> Node
zNode z =
    (zTableau z).node


zWalkPost : (Zipper -> Zipper) -> Zipper -> Zipper
zWalkPost f (( t, bs ) as z) =
    let
        ext =
            t.ext
    in
        case ext of
            Open ->
                f z

            Closed _ _ ->
                f z

            Alpha t ->
                z |> down |> zWalkPost f |> up |> f

            Beta tl tr ->
                z |> left |> zWalkPost f |> up |> right |> zWalkPost f |> up |> f


fixRefs : Zipper -> Zipper
fixRefs =
    zWalkPost (fixNodeRef >> fixClosedRefs)


getFixedRef : Ref -> Zipper -> Ref
getFixedRef ({ str, up } as ref) z =
    case up of
        Nothing ->
            { ref | str = "" }

        Just n ->
            { ref | str = z |> above n |> zNode |> .id |> toString }


fixNodeRef : Zipper -> Zipper
fixNodeRef z =
    modifyNode
        (\t ->
            let
                node =
                    t.node
            in
                { t | node = { node | reference = (getFixedRef node.reference z) } }
        )
        z


fixClosedRefs : Zipper -> Zipper
fixClosedRefs z =
    z
        |> modifyNode
            (\t ->
                let
                    ext =
                        t.ext

                    node =
                        t.node
                in
                    case ext of
                        Closed ref1 ref2 ->
                            Tableau node (Closed (getFixedRef ref1 z) (getFixedRef ref2 z))

                        _ ->
                            t
            )


renumber : Tableau -> Tableau
renumber tableau =
    renumber2 tableau 0
        |> Tuple.first
        |> zipper
        |> fixRefs
        |> top
        |> zTableau


renumber2 : Tableau -> Int -> ( Tableau, Int )
renumber2 tableau num =
    case tableau.ext of
        Open ->
            let
                node =
                    tableau.node

                ext =
                    tableau.ext
            in
                ( Tableau { node | id = num + 1 } ext, num + 1 )

        Alpha tableau ->
            let
                ( new_tableau, num1 ) =
                    renumber2 tableau (num + 1)

                node =
                    tableau.node

                new_ext =
                    new_tableau.ext
            in
                ( Tableau { node | id = num + 1 } new_ext, num1 )

        Beta lt rt ->
            let
                ( new_left, num1 ) =
                    renumber2 lt (num + 1)

                ( new_right, num2 ) =
                    renumber2 rt num1

                node =
                    tableau.node
            in
                ( (Tableau { node | id = num + 1 } (Beta new_left new_right)), num2 )

        _ ->
            ( tableau, num )


modifyRef : Ref -> Zipper -> Zipper
modifyRef ref z =
    modifyNode
        (\tableau ->
            let
                node =
                    tableau.node
            in
                { tableau | node = { node | reference = ref } }
        )
        z


findAbove : Int -> Zipper -> Maybe Int
findAbove ref ( tableau, bs ) =
    let
        node =
            tableau.node
    in
        if node.id == ref then
            Just 0
        else
            case bs of
                a :: bbs ->
                    Maybe.map ((+) 1) (( tableau, bs ) |> up |> findAbove ref)

                [] ->
                    Nothing


getRef : String -> Zipper -> Ref
getRef ref z =
    { str = ref
    , up =
        ref
            |> String.toInt
            |> Result.toMaybe
            |> Maybe.andThen ((flip findAbove) z)
    }



--Actions


setFormula : String -> Zipper -> Zipper
setFormula text =
    modifyNode
        (\tableau ->
            let
                oldNode =
                    tableau.node
            in
                { tableau | node = { oldNode | value = text } }
        )


setRef : String -> Zipper -> Zipper
setRef new z =
    z |> modifyRef (getRef new z)


extendAlpha : Zipper -> Zipper
extendAlpha (( t, bs ) as z) =
    modifyNode
        (\tableau ->
            case tableau.ext of
                Open ->
                    Tableau tableau.node (Alpha (Tableau defNode Open))

                _ ->
                    --tuto dopisat v pripade extendovania nie len pod leafs
                    tableau
        )
        z


extendBeta : Zipper -> Zipper
extendBeta z =
    z
        |> modifyNode
            (\tableau ->
                case tableau.ext of
                    Open ->
                        Tableau tableau.node (Beta (Tableau defNode Open) (Tableau defNode Open))

                    _ ->
                        tableau
            )


delete : Zipper -> Zipper
delete z =
    modifyNode (\tableau -> Tableau defNode Open) z


makeClosed : Zipper -> Zipper
makeClosed z =
    modifyNode
        (\tableau ->
            case tableau.ext of
                Open ->
                    Tableau tableau.node (Closed defRef defRef)

                _ ->
                    tableau
        )
        z
