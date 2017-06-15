{-
Copyright 2017 SlamData, Inc.
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

module SlamData.AdminUI.Component
  ( component
  ) where

import SlamData.Prelude

import Data.Array as Array
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import SlamData.AdminUI.Group as Group
import SlamData.AdminUI.Types as AT
import SlamData.Monad (Slam)
import SlamData.Workspace.MillerColumns.Component as Miller

component ∷ H.Component HH.HTML AT.Query Unit Void Slam
component =
  H.lifecycleParentComponent
    { initialState: \_ →
       { open: false
       , active: AT.MySettings
       , formState:
          { mySettings: AT.defaultMySettingsState
          , database: AT.defaultDatabaseState
          , server: AT.defaultServerState
          , groups: AT.defaultGroupsState
          }
       }
    , render
    , eval
    , initializer: Just (H.action AT.Init)
    , finalizer: Nothing
    , receiver: const Nothing
    }

render ∷ AT.State → AT.HTML
render state =
  HH.div
    [ HP.classes $ fold
        [ pure (H.ClassName "sd-admin-ui")
        , guard (not state.open) $> H.ClassName "hidden"
        ]
    ]
    [ tabHeader state.active
    , tabBody state
    , HH.button
        [ HE.onClick (HE.input_ AT.Close) ]
        [ HH.text "Close" ]
    ]

tabHeader ∷ AT.TabIndex → AT.HTML
tabHeader active =
  HH.ul
    [ HP.class_ $ H.ClassName "tabs"]
    $ Array.fromFoldable
    $ AT.allTabs <#> \t →
      HH.li
        (fold
          [ pure $ HE.onClick $ HE.input_ $ AT.SetActive t
          , guard (t == active) $> HP.class_ (H.ClassName "active-tab")
          ])
        [ HH.text (AT.tabTitle t) ]

tabBody ∷ AT.State → AT.HTML
tabBody state =
  HH.form
    [HP.class_ $ HH.ClassName "tab-body"]
    case state.active of
      AT.MySettings →
        pure $ HH.div
          [ HP.class_ (HH.ClassName "my-settings") ]
          (renderMySettingsForm state.formState.mySettings)
      AT.Database →
        pure $ HH.div
          [ HP.class_ (HH.ClassName "database") ]
          (renderDatabaseForm state.formState.database)
      AT.Server →
        pure $ HH.div
          [ HP.class_ (HH.ClassName "server") ]
          (renderServerForm state.formState.server)
      AT.Groups →
        pure $ HH.div
          [ HP.class_ (HH.ClassName "groups") ]
          (Group.renderGroupsForm state.formState.groups)
      _ →
        [HH.text "Not implemented"]
      -- Authentication → ?x
      -- Users → ?x

-- TODO(Christoph): Talk to Kyle
themes ∷ Array String
themes = ["Dark", "Light"]

renderMySettingsForm ∷ AT.MySettingsState → Array AT.HTML
renderMySettingsForm (AT.MySettingsState state) =
    [ HH.fieldset
        [ HP.class_ (HH.ClassName "home-directory") ]
        [ HH.legend_ [ HH.text "Location of my home directory in the SlamData file system:" ]
        , HH.input
            [ HP.classes [ HH.ClassName "form-control" ]
            , HP.id_ "HomeDirectory"
            , HP.value state.homeDirectory
            ]
        , HH.div
            [ HP.classes [ HH.ClassName "form-group" ] ]
            [ HH.div
                [ HP.classes [ HH.ClassName "checkbox" ] ]
                [ HH.label_
                    [ HH.input
                        [ HP.checked state.isolateArtifacts
                        , HP.type_ HP.InputCheckbox
                        ]
                    , HH.text "Isolate SlamData artifacts to a specific location in the SlamData file system"
                    ]
                ]
            , HH.input
                [ HP.classes [ HH.ClassName "form-control" ]
                , HP.id_ "IsolateLocation"
                , HP.disabled (not state.isolateArtifacts)
                , HP.value state.isolateArtifactsDirectory
                ]
            , HH.p_
                [ HH.text $
                  fold
                  [ "If you choose this option, while you can still virtually locate decks anywhere inside the file system, "
                  , "they will always be physically stored in the above location. This allows you to keep production systems "
                  , "free of SlamData artifacts, while still centrally locating and backing them up."
                  ]
                ]
            ]
        ]
    , HH.fieldset
        [ HP.class_ (HH.ClassName "themes") ]
        [ HH.legend_ [ HH.text "Default theme for new decks:" ]
        , HH.div
            [ HP.class_ (HH.ClassName "theme-pickers") ]
            [ HH.select
                [ HP.classes [ HH.ClassName "form-control" ]
                , HP.id_ "ThemeSelection"
                ]
                (themes <#> \t → HH.option_ [HH.text t])
            , HH.select
                [ HP.classes [ HH.ClassName "form-control" ]
                , HP.id_ "ThemeSpacing"
                ]
                (themes <#> \t → HH.option_ [HH.text t])
            ]
        ]
    ]

renderDatabaseForm ∷ AT.DatabaseState → Array AT.HTML
renderDatabaseForm (AT.DatabaseState state) =
  [ HH.fieldset
    [ HP.class_ (HH.ClassName "database-form-wrapper")]
    [ HH.legend
        [ HP.class_ (HH.ClassName "checkbox") ]
        [ HH.label_
            [ HH.input
                [ HP.checked (not state.isExternal)
                , HE.onChecked (HE.input_ (AT.SetDatabase (AT.DatabaseState (state {isExternal = false}) )))
                , HP.type_ HP.InputCheckbox
                ]
            , HH.text "Store SlamData metadata inside internal database in the local file system of the server"
            ]
        ]
    , HH.fieldset
        [ HP.class_ (HH.ClassName "internal-storage")
        , HP.disabled state.isExternal
        ]
        [ HH.input
            [ HP.classes [ HH.ClassName "form-control" ]
            , HP.value state.databaseFile
            ]
        ]
      , HH.legend
          [ HP.class_ (HH.ClassName "checkbox") ]
          [ HH.label_
              [ HH.input
                [ HP.checked state.isExternal
                , HE.onChecked (HE.input_ (AT.SetDatabase (AT.DatabaseState (state {isExternal = true}) )))
                , HP.type_ HP.InputCheckbox
                ]
              , HH.text "Store SlamData metadata inside external PostgreSQL"
              ]
          ]
      , HH.fieldset
          [ HP.class_ (HH.ClassName "external-storage")
          , HP.disabled (not state.isExternal)
          ]
          [ HH.div
              [ HP.class_ (HH.ClassName "form-group") ]
              [ HH.label [ HP.for "Server" ] [ HH.text "Server" ]
              , HH.input
                  [ HP.classes [ HH.ClassName "form-control" ]
                  , HP.id_ "Server"
                  , HP.value state.postgresCon.server
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "form-group") ]
              [ HH.label [ HP.for "Port" ] [ HH.text "Port" ]
              , HH.input
                  [ HP.classes [ HH.ClassName "form-control" ]
                  , HP.id_ "Port"
                  , HP.value (show state.postgresCon.port)
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "form-group") ]
              [ HH.label
                  [ HP.for "Username" ]
                  [ HH.text "Username"
                  , HH.input
                      [ HP.classes [ HH.ClassName "form-control" ]
                      , HP.id_ "Username"
                      , HP.value state.postgresCon.username
                      ]
                  ]
              , HH.label
                  [ HP.for "Password" ]
                  [ HH.text "Password"
                  , HH.input
                      [ HP.classes [ HH.ClassName "form-control" ]
                      , HP.id_ "Password"
                      , HP.value state.postgresCon.password
                      ]
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "form-group") ]
              [ HH.label [ HP.for "Database" ] [HH.text "Database"] , HH.input
                  [ HP.classes [ HH.ClassName "form-control" ]
                  , HP.id_ "Database"
                  , HP.value state.postgresCon.database
                  ]
              ]
          , HH.div
              [ HP.class_ (HH.ClassName "form-group") ]
              [ HH.label [ HP.for "Custom" ] [HH.text "Custom"]
              , HH.input
                  [ HP.classes [ HH.ClassName "form-control" ]
                  , HP.value (fst state.postgresCon.custom)
                  ]
              , HH.input
                  [ HP.classes [ HH.ClassName "form-control" ]
                  , HP.value (snd state.postgresCon.custom)
                  ]
              ]
          ]
      ]
  ]

renderServerForm ∷ AT.ServerState → Array AT.HTML
renderServerForm (AT.ServerState state) =
  [ HH.fieldset_
        [ HH.legend_ [ HH.text "Port" ]
        , HH.input
            [ HP.class_ (HH.ClassName "form-control") ]
        , HH.p_ [ HH.text "Changing the port will restart the server and reload the browser to the new port. If there are any errors in changing to the new port, however, you may have to use the browser back button."
                ]
        ]
  , HH.fieldset_
        [ HH.legend_ [HH.text "Location of log file in the SlamData file system"]
        , HH.input
            [ HP.class_ (HH.ClassName "form-control") ]
        ]
  , HH.fieldset_
        [ HH.legend
            [ HP.class_ (HH.ClassName "checkbox") ]
            [ HH.label_
              [ HH.input
                [ HP.checked state.enableCustomSSL
                , HE.onChecked (HE.input_ (AT.SetServer (AT.ServerState (state {enableCustomSSL = not state.enableCustomSSL}))))
                , HP.type_ HP.InputCheckbox
                ]
              , HH.text "Enable Custom SSL"
              ]
            ]
        , HH.textarea [HP.class_ (HH.ClassName "form-control"), HP.disabled (not state.enableCustomSSL)]
        ]
  ]

eval ∷ AT.Query ~> AT.DSL
eval = case _ of
  AT.Init next → do
    pure next
  AT.Open next → do
    H.modify (_ { open = true })
    pure next
  AT.Close next → do
    H.modify (_ { open = false })
    pure next
  AT.SetActive ix next → do
    H.modify (_ { active = ix })
    pure next
  AT.SetMySettings new next → do
    H.modify (_ { formState { mySettings = new } })
    pure next
  AT.SetDatabase new next → do
    H.modify (_ { formState { database = new } })
    pure next
  AT.SetServer new next → do
    H.modify (_ { formState { server = new } })
    pure next
  AT.SetGroups new next → do
    H.modify (_ { formState { groups = new } })
    pure next
  AT.HandleColumns columnMsg next → do
    case columnMsg of
      Miller.SelectionChanged _ _ _ →
        pure next
      Miller.LoadRequest req@(path × _) → do
        res ← Group.load req
        _ ← H.query' AT.cpGroups unit (H.action (Miller.FulfilLoadRequest (path × res)))
        pure next
  AT.HandleColumnOrItem columnMsg next → do
    pure next
