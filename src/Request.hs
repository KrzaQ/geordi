{-# LANGUAGE FlexibleInstances, UndecidableInstances, OverlappingInstances #-}

module Request (is_addressed_request, is_short_request, EditableRequest(..), EditableRequestKind(..), Context(..), Response(..), EvalOpt(..), EphemeralOpt(..), HistoryModification(..), modify_history) where

import Data.Set (Set)
import qualified Data.Set as Set
import qualified Text.ParserCombinators.Parsec as PS
import Control.Exception ()
import Data.Char (isAlpha, isDigit)
import Control.Monad.Error ()
import Text.ParserCombinators.Parsec (getInput, (<|>), oneOf, lookAhead, spaces, satisfy, CharParser, many1, string, parse)
import Util (Option(..), (.), (.||.), total_tail)
import Prelude hiding (catch, (.))

data EvalOpt = CompileOnly | Terse | NoWarn deriving (Eq, Enum, Bounded, Ord)

instance Option EvalOpt where
  short CompileOnly = 'c'
  short Terse = 't'
  short NoWarn = 'w'
  long CompileOnly = "compile-only"
  long Terse = "terse"
  long NoWarn = "no-warn"

data EphemeralOpt = Resume deriving (Eq, Enum, Bounded)

instance Option EphemeralOpt where short Resume = 'r'; long Resume = "resume"

type Nick = String

nickP :: CharParser st Nick
nickP = many1 $ satisfy $ isAlpha .||. isDigit .||. (`elem` "[]\\`_^|}-")
  -- We don't include '{' because it messes up "geordi{...}", and no sane person would use it in a nick for a geordi bot anyway.

is_short_request :: String -> Maybe String
is_short_request =
  either (const Nothing) Just . parse (spaces >> lookAhead (string "{" <|> string "<<") >> getInput) ""

is_addressed_request :: String -> Maybe (Nick, String)
is_addressed_request txt = either (const Nothing) Just (parse p "" txt)
  where
   p = do
    spaces
    nick <- nickP
    oneOf ":," <|> (spaces >> lookAhead (oneOf "<{-"))
    r <- getInput
    return (nick, r)

data Context = Context { request_history :: [EditableRequest] }

data EditableRequestKind = MakeType | Precedence | Evaluate (Set EvalOpt)
instance Show EditableRequestKind where
  show MakeType = "make type"
  show Precedence = "precedence"
  show (Evaluate s) = if Set.null s then "" else '-' : (short . Set.elems s)

data EditableRequest = EditableRequest { kind :: EditableRequestKind, editable_body :: String }

data HistoryModification = ReplaceLast EditableRequest | AddLast EditableRequest | DropLast

modify_history :: HistoryModification -> Context -> Context
modify_history m (Context l) = Context $ case m of
  ReplaceLast e -> e : total_tail l
  AddLast e -> e : l
  DropLast -> total_tail l

data Response = Response
  { response_history_modification :: Maybe HistoryModification
  , response_output :: String }
