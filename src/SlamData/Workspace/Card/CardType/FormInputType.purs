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

module SlamData.Workspace.Card.CardType.FormInputType
  ( FormInputType(..)
  , parse
  , print
  , name
  , lightIconSrc
  , darkIconSrc
  , all
  , maximumCountOfEntries
  , maximumCountOfSelectedValues
  , isLabeled
  , isStatic
  , isTextLike
  ) where

import SlamData.Prelude

import Data.Argonaut (fromString, class EncodeJson, class DecodeJson, decodeJson)

import Test.StrongCheck.Arbitrary as SC
import Test.StrongCheck.Gen as Gen

-- This data type is actually sum of three: LabeledLike, TextLike and Static
-- It's a bit inconvenient to use this like LabeledLike ⊹ TextLike ⊹ Static though.
-- (And unfortunately isn't very elegant to use this like ADT :( )
data FormInputType
  = Dropdown
  | Static
  | Text
  | Numeric
  | Checkbox
  | Radio
  | Date
  | Time
  | Datetime

instance showFormInputType ∷ Show FormInputType where
  show = case _ of
    Dropdown → "Dropdown"
    Static → "Static"
    Text → "Text"
    Numeric → "Numeric"
    Checkbox → "Checkbox"
    Radio → "Radio"
    Date → "Date"
    Time → "Time"
    Datetime → "Datetime"

isLabeled ∷ FormInputType → Boolean
isLabeled = case _ of
  Dropdown → true
  Checkbox → true
  Radio → true
  _ → false

isTextLike ∷ FormInputType → Boolean
isTextLike = case _ of
  Text → true
  Numeric → true
  Time → true
  Date → true
  Datetime → true
  _ → false

isStatic ∷ FormInputType → Boolean
isStatic = case _ of
  Static → true
  _ → false

all ∷ Array FormInputType
all =
  [ Dropdown
  , Static
  , Text
  , Numeric
  , Checkbox
  , Radio
  , Date
  , Time
  , Datetime
  ]

parse ∷ String → String ⊹ FormInputType
parse = case _ of
  "dropdown" → pure Dropdown
  "static" → pure Static
  "text" → pure Text
  "numeric" → pure Numeric
  "checkbox" → pure Checkbox
  "radio" → pure Radio
  "date" → pure Date
  "time" → pure Time
  "datetime" → pure Datetime
  _ → Left "incorrect formInputType"

print ∷ FormInputType → String
print = case _ of
  Dropdown → "dropdown"
  Static → "static"
  Text → "text"
  Numeric → "numeric"
  Checkbox → "checkbox"
  Radio → "radio"
  Date → "date"
  Time → "time"
  Datetime → "datetime"

name ∷ FormInputType → String
name = case _ of
  Dropdown → "Dropdown"
  Static → "Static Text"
  Text → "Text Input"
  Numeric → "Numeric Input"
  Checkbox → "Checkbox Group"
  Radio → "Radio Group"
  Date → "Date Input"
  Time → "Time Input"
  Datetime → "Date/Time Input"

derive instance eqFormInputType ∷ Eq FormInputType
derive instance ordFormInputType ∷ Ord FormInputType

instance encodeJsonFormInputType ∷ EncodeJson FormInputType where
  encodeJson = fromString ∘ print

instance decodeJsonFormInputType ∷ DecodeJson FormInputType where
  decodeJson = decodeJson >=> parse

instance arbitraryFormInputType ∷ SC.Arbitrary FormInputType where
  arbitrary = Gen.allInArray all

lightIconSrc ∷ FormInputType → String
lightIconSrc = case _ of
  Dropdown → "img/formInputs/light/dropdown.svg"
  Static → "img/formInputs/light/static.svg"
  Text → "img/formInputs/light/text.svg"
  Numeric → "img/formInputs/light/numeric.svg"
  Checkbox → "img/formInputs/light/checkbox.svg"
  Radio → "img/formInputs/light/radio.svg"
  Date → "img/formInputs/light/date.svg"
  Time → "img/formInputs/light/time.svg"
  Datetime → "img/formInputs/light/datetime.svg"

darkIconSrc ∷ FormInputType → String
darkIconSrc = case _ of
  Dropdown → "img/formInputs/dark/dropdown.svg"
  Static → "img/formInputs/dark/static.svg"
  Text → "img/formInputs/dark/text.svg"
  Numeric → "img/formInputs/dark/numeric.svg"
  Checkbox → "img/formInputs/dark/checkbox.svg"
  Radio → "img/formInputs/dark/radio.svg"
  Date → "img/formInputs/dark/date.svg"
  Time → "img/formInputs/dark/time.svg"
  Datetime → "img/formInputs/dark/datetime.svg"

-- If there is more records in JArray don't even try to display it in ShowFormInput
maximumCountOfEntries ∷ FormInputType → Int
maximumCountOfEntries = case _ of
  Dropdown → 1000
  Radio → 1000
  Checkbox → 1000
  _ → top

maximumCountOfSelectedValues ∷ FormInputType → Int
maximumCountOfSelectedValues = case _ of
  Dropdown → 1
  Radio → 1
  _ → top
