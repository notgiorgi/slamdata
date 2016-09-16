
{-
Copyright 2016 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module SlamData.Workspace.Card.BuildChart.PivotTable.Component where

import SlamData.Prelude

import Data.Array as Array
import Data.Int (toNumber)

import CSS as C
import Halogen as H
import Halogen.Component.Utils.Drag as Drag
import Halogen.HTML.Indexed as HH
import Halogen.HTML.Events.Indexed as HE
import Halogen.HTML.Properties.Indexed as HP
import Halogen.HTML.Properties.Indexed.ARIA as ARIA
import Halogen.HTML.CSS.Indexed as HC

import SlamData.Form.Select as S
import SlamData.Monad (Slam)
import SlamData.Workspace.Card.BuildChart.PivotTable.Component.ChildSlot as PCS
import SlamData.Workspace.Card.BuildChart.PivotTable.Component.Query (Query(..), QueryC)
import SlamData.Workspace.Card.BuildChart.PivotTable.Component.State (State, modelFromState, stateFromModel, initialState, reorder, setColumnAggregation)
import SlamData.Workspace.Card.BuildChart.PivotTable.Model (Column(..))
import SlamData.Workspace.Card.CardType as CT
import SlamData.Workspace.Card.CardType.ChartType as CHT
import SlamData.Workspace.Card.Chart.Aggregation as Ag
import SlamData.Workspace.Card.Common.Render (renderLowLOD)
import SlamData.Workspace.Card.Component as CC
import SlamData.Workspace.Card.Model as Card
import SlamData.Workspace.Card.Port as Port
import SlamData.Workspace.LevelOfDetails (LevelOfDetails(..))

type DSL = H.ParentDSL State PCS.ChildState QueryC PCS.ChildQuery Slam PCS.ChildSlot

type HTML = H.ParentHTML PCS.ChildState QueryC PCS.ChildQuery Slam PCS.ChildSlot

pivotTableBuilderComponent ∷ CC.CardComponent
pivotTableBuilderComponent = CC.makeCardComponent
  { cardType: CT.ChartOptions CHT.PivotTable
  , component: H.parentComponent
      { render
      , eval: coproduct evalCard evalOptions
      , peek: Just peek
      }
  , initialState: H.parentState initialState
  , _State: CC._BuildPivotTableState
  , _Query: CC.makeQueryPrism' CC._BuildPivotTableQuery
  }

render ∷ State → HTML
render st =
  if st.levelOfDetails ≡ High
    then renderHighLOD st
    else renderLowLOD (CT.darkCardGlyph (CT.ChartOptions CHT.PivotTable)) left st.levelOfDetails

renderHighLOD ∷ State → HTML
renderHighLOD st =
  HH.div
    [ HP.classes [ HH.className "sd-pivot-options" ] ]
    [ HH.div
        [ HP.classes [ HH.className "sd-pivot-options-corner" ] ]
        [ HH.span_ [ HH.text "Dimensions" ]
        , HH.span_ [ HH.text "Columns" ]
        ]
    , HH.div
        [ HP.classes [ HH.className "sd-pivot-options-dims" ] ]
        renderedDimensions
    , HH.div
        [ HP.classes [ HH.className "sd-pivot-options-cols" ] ]
        renderedColumns
    , maybe (HH.text "") renderSelect st.selectDimension
    , maybe (HH.text "") renderSelect st.selectColumn
    ]
  where
  renderSelect (cs × _) =
    HH.div
      [ HP.classes [ HH.className "sd-pivot-options-select" ] ]
      [ HH.select
          [ HE.onSelectedIndexChange (HE.input (\ix → right ∘ ChangeAxis ix)) ]
          (map (\c → HH.option_ [ HH.text (show c) ]) cs)
      , HH.button
          [ HE.onClick (HE.input_ (right ∘ ChooseAxis false)) ]
          [ HH.text "Dismiss" ]
      , HH.button
          [ HE.onClick (HE.input_ (right ∘ ChooseAxis true)) ]
          [ HH.text "Confirm" ]
      ]

  renderedDimensions =
    let
      len  = Array.length st.dimensions + 1
      size = 100.0 / toNumber len
    in
      map (renderDimension size) st.dimensions <>
      [ HH.div
          [ HP.classes [ HH.className "sd-pivot-options-dim" ]
          , HC.style (C.height (C.pct size))
          ]
          [ HH.div
              [ HP.classes [ HH.className "sd-pivot-options-dim-inner"] ]
              [ HH.button
                  [ HP.classes [ HH.className "sd-pivot-options-plus" ]
                  , HE.onClick (HE.input_ (right ∘ AddDimension))
                  ]
                  []
              ]
          ]
      ]

  renderDimension size (slot × dim) =
    HH.div
      ([ HP.classes (dimensionClasses slot)
       , HC.style (C.height (C.pct size))
       ] <> dimensionEvents slot)
      [ HH.div
          [ HP.classes [ HH.className "sd-pivot-options-dim-inner"]
          , HC.style (dimensionStyles slot size)
          ]
          [ HH.button
              [ HP.classes [ HH.className "sd-pivot-options-label" ]
              , HE.onMouseDown (HE.input (\e → right ∘ OrderDimensionStart slot e))
              ]
              [ HH.text (show dim) ]
          , HH.button
              [ HP.classes [ HH.className "delete-cell" ]
              , HP.title "Delete dimension"
              , ARIA.label "Delete dimension"
              , HE.onClick (HE.input_ (right ∘ RemoveDimension slot))
              ]
              [ HH.text "×"]
          ]
      ]

  dimensionClasses slot =
    [ HH.className "sd-pivot-options-dim" ] <>
      case st.orderingDimension of
        Just opts | opts.source == slot → [ HH.className "ordering" ]
        Just opts | opts.over == Just slot → [ HH.className "ordering-over" ]
        _ → []

  dimensionStyles slot size = do
    case st.orderingDimension of
      Just opts | opts.source == slot → C.top (C.px opts.offset)
      _ → pure unit

  dimensionEvents slot =
    if isJust st.orderingDimension
      then
        [ HE.onMouseOver (HE.input_ (right ∘ OrderOverDimension slot))
        , HE.onMouseOut (HE.input_ (right ∘ OrderOutDimension slot))
        ]
      else
        []

  renderedColumns =
    let
      len  = Array.length st.columns + 1
      size = 100.0 / toNumber len
    in
      map (renderColumn size) st.columns <>
      [ HH.div
          [ HP.classes [ HH.className "sd-pivot-options-col" ]
          , HC.style (C.width (C.pct size))
          ]
          [ HH.div
              [ HP.classes [ HH.className "sd-pivot-options-col-inner"] ]
              [ HH.div
                  [ HP.classes [ HH.className "sd-pivot-options-col-value" ] ]
                  [ HH.button
                      [ HP.classes [ HH.className "sd-pivot-options-plus" ]
                      , HE.onClick (HE.input_ (right ∘ AddColumn))
                      ]
                      []
                  ]
              , HH.div
                  [ HP.classes [ HH.className "sd-pivot-options-col-aggregation" ] ]
                  []
              ]
          ]
      ]

  renderColumn size (slot × (Column col)) =
    HH.div
      ([ HP.classes (columnClasses slot)
       , HC.style (C.width (C.pct size))
       ] <> columnEvents slot)
      [ HH.div
          [ HP.classes [ HH.className "sd-pivot-options-col-inner"]
          , HC.style (columnStyles slot size)
          ]
          [ HH.div
              [ HP.classes [ HH.className "sd-pivot-options-col-value" ] ]
              [ HH.button
                  [ HP.classes [ HH.className "sd-pivot-options-label" ]
                  , HE.onMouseDown (HE.input (\e → right ∘ OrderColumnStart slot e))
                  ]
                  [ HH.text (show col.value) ]
              , HH.button
                  [ HP.classes [ HH.className "delete-cell" ]
                  , HP.title "Delete column"
                  , ARIA.label "Delete column"
                  , HE.onClick (HE.input_ (right ∘ RemoveColumn slot))
                  ]
                  [ HH.text "×"]
              ]
          , HH.div
              [ HP.classes [ HH.className "sd-pivot-options-col-aggregation" ] ]
              [ HH.button
                  [ HP.classes
                      [ HH.className "btn"
                      , HH.className "btn-primary"
                      , HH.className "aggregation"
                      , HH.className (S.stringVal col.valueAggregation)
                      ]
                  , HE.onClick (HE.input_ (right ∘ ChangeAggregation slot))
                  ]
                  []
              , columnSelect slot col.valueAggregation
              ]
          ]
      ]

  columnClasses slot =
    [ HH.className "sd-pivot-options-col" ] <>
      case st.orderingColumn of
        Just opts | opts.source == slot → [ HH.className "ordering" ]
        Just opts | opts.over == Just slot → [ HH.className "ordering-over" ]
        _ → []

  columnStyles slot size = do
    case st.orderingColumn of
      Just opts | opts.source == slot → C.left (C.px opts.offset)
      _ → pure unit

  columnEvents slot =
    if isJust st.orderingColumn
      then
        [ HE.onMouseOver (HE.input_ (right ∘ OrderOverColumn slot))
        , HE.onMouseOut (HE.input_ (right ∘ OrderOutColumn slot))
        ]
      else
        []

  columnSelect slot ag =
    case st.selectAggregation of
      Just slot' | slot' == slot →
        HH.div
          [ HP.classes [ HH.className "list-group" ] ]
          (map (selectBtn ag)
            [ Nothing
            , Just Ag.Maximum
            , Just Ag.Minimum
            , Just Ag.Average
            , Just Ag.Sum
            , Just Ag.Product
            ])
      _ →
        HH.text ""

  selectBtn ag ctr =
    HH.button
      [ HP.classes
          ([ HH.className "list-group-item" ]
           <> (HH.className "active" <$ guard (ctr == ag)))
      , HE.onClick (HE.input_ (right ∘ ChooseAggregation ctr))
      ]
      [ HH.text (S.stringVal ctr) ]

evalCard ∷ CC.CardEvalQuery ~> DSL
evalCard = case _ of
  CC.EvalCard info _ next → do
    case info.input of
      Just (Port.TaggedResource { axes }) →
        H.modify _ { axes = axes }
      _ → pure unit
    pure next
  CC.Activate next →
    pure next
  CC.Deactivate next →
    pure next
  CC.SetDimensions _ next →
    pure next
  CC.Save k →
    map (k ∘ Card.BuildPivotTable ∘ modelFromState) H.get
  CC.Load card next → do
    case card of
      Card.BuildPivotTable model →
        H.modify (stateFromModel model)
      _ → pure unit
    pure next
  CC.ModelUpdated _ next →
    pure next
  CC.ZoomIn next →
    pure next

evalOptions ∷ Query ~> DSL
evalOptions = case _ of
  AddDimension next → do
    H.modify \st →
      let
        cursors = Array.sort (st.axes.category <> st.axes.time <> st.axes.value)
      in
        st { selectDimension = Just (cursors × 0) }
    CC.raiseUpdatedP' CC.EvalModelUpdate
    pure next
  AddColumn next → do
    H.modify \st →
      let
        cursors = Array.sort (st.axes.category <> st.axes.time <> st.axes.value)
      in
        st { selectColumn = Just (cursors × 0) }
    CC.raiseUpdatedP' CC.EvalModelUpdate
    pure next
  RemoveDimension slot next → do
    H.modify \st →
      st { dimensions = Array.filter (not ∘ eq slot ∘ fst) st.dimensions }
    CC.raiseUpdatedP' CC.EvalModelUpdate
    pure next
  RemoveColumn slot next → do
    H.modify \st →
      st { columns = Array.filter (not ∘ eq slot ∘ fst) st.columns }
    CC.raiseUpdatedP' CC.EvalModelUpdate
    pure next
  OrderDimensionStart slot ev next → do
    let
      opts =
        { source: slot
        , over: Nothing
        , offset: 0.0
        }
    Drag.subscribe' ev (right ∘ H.action ∘ OrderingDimension slot)
    H.modify _ { orderingDimension = Just opts }
    pure next
  OrderingDimension slot ev next → do
    st ← H.get
    for_ st.orderingDimension \opts →
      case ev of
        Drag.Move _ d →
          H.modify _ { orderingDimension = Just opts { offset = d.offsetY } }
        Drag.Done _ →
          case opts.over of
            Just slot' → do
              H.modify _
                { orderingDimension = Nothing
                , dimensions = reorder slot slot' st.dimensions
                }
              CC.raiseUpdatedP' CC.EvalModelUpdate
            Nothing →
              H.modify _ { orderingDimension = Nothing }
    pure next
  OrderOverDimension slot next → do
    st ← H.get
    for_ st.orderingDimension \opts →
      H.modify _ { orderingDimension = Just (opts { over = Just slot }) }
    pure next
  OrderOutDimension slot next → do
    st ← H.get
    for_ st.orderingDimension \opts →
      H.modify _ { orderingDimension = Just (opts { over = Nothing }) }
    pure next
  OrderColumnStart slot ev next → do
    let
      opts =
        { source: slot
        , over: Nothing
        , offset: 0.0
        }
    Drag.subscribe' ev (right ∘ H.action ∘ OrderingColumn slot)
    H.modify _ { orderingColumn = Just opts }
    pure next
  OrderingColumn slot ev next → do
    st ← H.get
    for_ st.orderingColumn \opts →
      case ev of
        Drag.Move _ d →
          H.modify _ { orderingColumn = Just opts { offset = d.offsetX } }
        Drag.Done _ →
          case opts.over of
            Just slot' → do
              H.modify _
                { orderingColumn = Nothing
                , columns = reorder slot slot' st.columns
                }
              CC.raiseUpdatedP' CC.EvalModelUpdate
            Nothing →
              H.modify _ { orderingColumn = Nothing }
    pure next
  OrderOverColumn slot next → do
    st ← H.get
    for_ st.orderingColumn \opts →
      H.modify _ { orderingColumn = Just (opts { over = Just slot }) }
    pure next
  OrderOutColumn slot next → do
    st ← H.get
    for_ st.orderingColumn \opts →
      H.modify _ { orderingColumn = Just (opts { over = Nothing }) }
    pure next
  ChangeAxis ix next → do
    st ← H.get
    for_ st.selectDimension \(ds × _) →
      H.modify _ { selectDimension = Just (ds × ix)}
    for_ st.selectColumn \(cs × _) →
      H.modify _ { selectColumn = Just (cs × ix)}
    pure next
  ChooseAxis bool next → do
    when bool do
      st ← H.get
      for_ st.selectDimension \(ds × ix) → do
        let
          dim = Tuple st.fresh <$> Array.index ds ix
        H.modify _
          { fresh = st.fresh + 1
          , dimensions = st.dimensions <> maybe [] pure dim
          }
      for_ st.selectColumn \(cs × ix) → do
        let
          col = Tuple st.fresh ∘ Column ∘ { value: _, valueAggregation: Nothing } <$> Array.index cs ix
        H.modify _
          { fresh = st.fresh + 1
          , columns = st.columns <> maybe [] pure col
          }
    H.modify _
      { selectColumn = Nothing
      , selectDimension = Nothing
      }
    CC.raiseUpdatedP' CC.EvalModelUpdate
    pure next
  ChangeAggregation slot next → do
    st ← H.get
    case st.selectAggregation of
      Just slot' | slot' == slot →
        H.modify _ { selectAggregation = Nothing }
      _ →
        H.modify _ { selectAggregation = Just slot }
    pure next
  ChooseAggregation ag next → do
    st ← H.get
    for_ st.selectAggregation \slot → do
      H.modify (setColumnAggregation slot ag)
      CC.raiseUpdatedP' CC.EvalModelUpdate
    H.modify _ { selectAggregation = Nothing }
    pure next

peek ∷ ∀ a. H.ChildF PCS.ChildSlot PCS.ChildQuery a → DSL Unit
peek _ = pure unit
