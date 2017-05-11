module SlamData.Workspace.Card.Setups.Geo.Marker.Eval
  ( eval
  , module SlamData.Workspace.Card.Setups.Geo.Marker.Model
  ) where

import SlamData.Prelude

import Color as C

import Data.Array as A
import Data.Argonaut (Json, decodeJson, (.?))
import Data.List as L
import Data.StrMap as Sm
import Data.String as S
import Data.Foldable as F
import Data.Int as Int

import Leaflet.Core as LC

import Math ((%))

import SlamData.Workspace.Card.Port as Port
import SlamData.Workspace.Card.Setups.Axis (Axes)
import SlamData.Workspace.Card.Setups.Chart.Common as SCC
import SlamData.Workspace.Card.Setups.Geo.Marker.Model (ModelR, Model)
import SlamData.Workspace.Card.Setups.Common.Eval as BCE
import SlamData.Workspace.Card.Setups.Semantics as Sem
import SlamData.Workspace.Card.Setups.Chart.ColorScheme (colors)

import SqlSquared as Sql

import Utils.Array (enumerate)

eval ∷ ∀ m. BCE.ChartSetupEval ModelR m
eval = BCE.chartSetupEval (SCC.buildBasicSql buildProjections buildGroupBy) buildMarker

buildProjections ∷ ModelR → L.List (Sql.Projection Sql.Sql)
buildProjections r = L.fromFoldable
  $ [ r.lat # SCC.jcursorPrj # Sql.as "lat"
    , r.lng # SCC.jcursorPrj # Sql.as "lng"
    , r.series # maybe SCC.nullPrj SCC.jcursorPrj # Sql.as "series"
    , sizeField
    ]
  ⊕ ( map mkProjection $ enumerate r.dims )
  where
  sizeField = case r.size of
    Nothing → SCC.nullPrj # Sql.as "size"
    Just sz → sz # SCC.jcursorPrj # Sql.as "size" # SCC.applyTransform sz
  mkProjection (ix × field) =
    field # SCC.jcursorPrj # Sql.as ("measure" ⊕ show ix) # SCC.applyTransform field

buildGroupBy ∷ ModelR → Maybe (Sql.GroupBy Sql.Sql)
buildGroupBy r =
  SCC.groupBy $ L.fromFoldable $ A.catMaybes
    [ Just $ SCC.jcursorSql r.lat
    , Just $ SCC.jcursorSql r.lng
    , map SCC.jcursorSql r.series
    ]

type Item =
  { lat ∷ LC.Degrees
  , lng ∷ LC.Degrees
  , size ∷ Number
  , series ∷ String
  , dims ∷ Array Number
  }

decodeItem ∷ Json → String ⊹ Item
decodeItem = decodeJson >=> \obj → do
  latSem ← obj .? "lat"
  lngSem ← obj .? "lng"
  latNum ← maybe (Left "lat has incorrect semantics") Right $ Sem.maybeNumber latSem
  lngNum ← maybe (Left "lng has incorrect semantics") Right $ Sem.maybeNumber lngSem
  lat ← maybe (Left "incorrect degrees, should be impossible") Right $ LC.mkDegrees $ latNum % 360.0
  lng ← maybe (Left "incorrect degrees, should be impossible") Right $ LC.mkDegrees $ lngNum % 360.0
  size ← map (fromMaybe zero ∘ Sem.maybeNumber) $ obj .? "size"
  series ← map (fromMaybe "" ∘ Sem.maybeString) $ obj .? "series"
  let
    ks ∷ Array String
    ks = map ("measure" <> _) $ A.mapMaybe (S.stripPrefix $ S.Pattern "measure") $ Sm.keys obj
  dims ← for ks \k →
    map (fromMaybe zero ∘ Sem.maybeNumber) $ obj .? k
  pure { lat
       , lng
       , size
       , series
       , dims
       }

buildMarker ∷ ModelR → Axes → Port.Port
buildMarker r _ =
  Port.GeoChart { build }
  where
  mkItems ∷ Array Json → Array Item
  mkItems = foldMap (foldMap A.singleton ∘ decodeItem)

  mkMaxLat ∷ Array Item → Number
  mkMaxLat = fromMaybe zero ∘ A.head ∘ A.reverse ∘ A.sort ∘ map (LC.degreesToNumber ∘ _.lat)

  mkMaxLng ∷ Array Item → Number
  mkMaxLng = fromMaybe zero ∘ A.head ∘ A.reverse ∘ A.sort ∘ map (LC.degreesToNumber ∘ _.lng)

  mkMinLat ∷ Array Item → Number
  mkMinLat = fromMaybe zero ∘ A.head ∘ A.sort ∘ map (LC.degreesToNumber ∘ _.lat)

  mkMinLng ∷ Array Item → Number
  mkMinLng = fromMaybe zero ∘ A.head ∘ A.sort ∘ map (LC.degreesToNumber ∘ _.lng)

  mkAvgLat ∷ Array Item → Number
  mkAvgLat items =
    F.sum lats / (Int.toNumber $ A.length lats)
    where
    lats = map (LC.degreesToNumber ∘ _.lat) items

  mkAvgLng ∷ Array Item → Number
  mkAvgLng items =
    F.sum lngs / (Int.toNumber $ A.length lngs)
    where
    lngs = map (LC.degreesToNumber ∘ _.lng) items

  mkMinSize ∷ Array Item → Number
  mkMinSize = fromMaybe zero ∘ A.head ∘ A.sort ∘ map _.size

  mkMaxSize ∷ Array Item → Number
  mkMaxSize = fromMaybe one ∘ A.head ∘ A.reverse ∘ A.sort ∘ map _.size

  mkSeries ∷ Array Item → Sm.StrMap C.Color
  mkSeries items = Sm.fromFoldable $ A.zip (A.sort $ A.nub $ map _.series items) colors

  build leaf records = do
    let
      items = mkItems records
      minLng = mkMinLng items
      maxLng = mkMaxLng items
      minLat = mkMinLat items
      maxLat = mkMaxLat items
      latDiff = maxLat - minLat
      lngDiff = maxLng - minLng
      avgLat = mkAvgLat items
      avgLng = mkAvgLng items
      zoomLat = 360.0 / latDiff
      zoomLng = 360.0 / lngDiff
      zoomInt = min (Int.floor zoomLat) (Int.floor zoomLng)
      series = mkSeries items
      minSize = mkMinSize items
      maxSize = mkMaxSize items
      sizeDistance = r.maxSize - r.minSize
      distance = maxSize - minSize
      mkRadius size
        | distance ≡ 0.0 = minSize
        | otherwise = r.maxSize - sizeDistance / distance * (maxSize - size)
      foldFn acc item@{lat, lng} = do
        cm ←
          LC.circleMarker
          {lat, lng}
          { radius: mkRadius item.size
          , color: unsafePartial fromJust $ Sm.lookup item.series series
          }
        pure $ A.cons (LC.circleMarkerToLayer cm) acc

    zoom ← LC.mkZoom zoomInt

    view ← LC.mkLatLng avgLat avgLng

    layers ← A.foldRecM foldFn [ ] items

    _ ← LC.setZoom zoom leaf
    LC.once "zoomend" (const $ void $ LC.setView view leaf) $ LC.mapToEvented leaf

    pure layers
