{-
Copyright 2015 SlamData, Inc.

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

module Test.SlamData.Property.Workspace.Card.Model
  ( ArbCard
  , runArbCard
  , check
  , checkCardEquality
  ) where

import Prelude

import Data.Argonaut as J
import Data.Either (Either(..))
import Data.Foldable (mconcat)

import SlamData.Workspace.Card.Model as Card

import Test.SlamData.Property.Workspace.Card.CardId (runArbCardId)

import Test.StrongCheck ((<?>))
import Test.StrongCheck as SC

newtype ArbCard = ArbCard Card.Model

runArbCard ∷ ArbCard → Card.Model
runArbCard (ArbCard m) = m

instance arbitraryArbCard ∷ SC.Arbitrary ArbCard where
  arbitrary = do
    cardId ← runArbCardId <$> SC.arbitrary
    model ← SC.arbitrary
    pure $ ArbCard { cardId, model }

check ∷ SC.QC Unit
check =
  SC.quickCheck $ runArbCard >>> \model →
    case Card.decode (Card.encode model) of
      Left err -> SC.Failed $ "Decode failed: " ++ err
      Right model' -> checkCardEquality model model'

checkCardEquality ∷ Card.Model → Card.Model → SC.Result
checkCardEquality model model' =
  mconcat
   [ model.cardId == model'.cardId <?> "cardId mismatch"
   , model.model == model'.model <?> ("model mismatch:\n " <> show (J.encodeJson model.model) <> "\n" <> show (J.encodeJson model'.model))
   ]
