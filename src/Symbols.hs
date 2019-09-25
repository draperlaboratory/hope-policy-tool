{-
 - Copyright © 2017-2018 The Charles Stark Draper Laboratory, Inc. and/or Dover Microsystems, Inc.
 - All rights reserved.
 -
 - Use and disclosure subject to the following license.
 -
 - Permission is hereby granted, free of charge, to any person obtaining
 - a copy of this software and associated documentation files (the
 - "Software"), to deal in the Software without restriction, including
 - without limitation the rights to use, copy, modify, merge, publish,
 - distribute, sublicense, and/or sell copies of the Software, and to
 - permit persons to whom the Software is furnished to do so, subject to
 - the following conditions:
 -
 - The above copyright notice and this permission notice shall be
 - included in all copies or substantial portions of the Software.
 -
 - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 - EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 - MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 - NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 - LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 - OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 - WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 -}
module Symbols
  (ModSymbols, UsedSymbols, SymbolTable(..),
   buildSymbolTables,
   lookupType, lookupTag, lookupPolicy, lookupGroup,
   getTag, getType, getPolicy, getGroup,
   usedTags, usedTypes, usedGroups, usedRequires,
   resolveQSym, moduleForQSym, moduleTags)
where

import Data.List (intercalate, nub, sort)
import Data.Maybe (catMaybes)

import AST
import CommonFn
import ErrorMsg (mayErr,ErrMsg)

-- The Symbol module creates two data structures with symbols for the parsed
-- dpl files and provides a set of functions for querrying

-- Symbols Data Structures --

-- Module Symbols - An association list of full symbol tables for each parsed
-- dpl module.  Symbols could be a superset of what is used by a given policy.
type ModSymbols = [(ModName, SymbolTable QSym)]

-- UsedSymbols gives the actual list of Symbols used by the policy being
-- processed.  This is actually constructed in the Validate module, see:
-- validateMain Fn
type UsedSymbols = [(ModName, QSym)]

-- SymbolTable is split up by type of symbol
data SymbolTable n = SymbolTable
  { modDecl :: ModuleDecl QSym
  , importSyms :: [ModName]
  , typeSyms :: [(QSym, TypeDecl n)]
  , tagSyms :: [(QSym, TagDecl n)]
  , policySyms :: [(QSym, PolicyDecl n)]
  , groupSyms :: [(QSym, GroupDecl [ISA] n)]
  , requires :: [RequireDecl n]
  } deriving (Show)

-- Symbols API --
-- take a list of parsed module declarations and produce the symbol tables
buildSymbolTables :: [ModuleDecl QSym] -> Either [ErrMsg] ModSymbols
buildSymbolTables mods = symbolTables mods

-- Use these functions when the thing you are looking for may not exist
-- Lookup Fns return Either a Decl or an error message
type LookupResult a = Either ErrMsg (ModName, a)

{- Lookup functions take:

   - ModSymbols - the list of all module symbol tables
   - ModName: the module name where the qsym is refrenced from (to calculate
     the include graph)
   - QSym - the symbol to look for, may be qualified or unqualified

   The lookup will traverse the include graph locating all symbols with the
   specified name.  If the qsym is unqualified only one match must be found
   otherwise its an error.  If the qsym is qualified multiple matches in the
   include graph are allowed and the one matching the qualified name is
   returned.
-}
lookupType :: ModSymbols -> ModName -> QSym -> LookupResult (TypeDecl QSym)
lookupType ms mn qs = lookupQSym ms typeSyms mn qs

lookupTag :: ModSymbols -> ModName -> QSym -> LookupResult (TagDecl QSym)
lookupTag ms mn qs = lookupQSym ms tagSyms mn qs

lookupPolicy :: ModSymbols -> ModName -> QSym
             -> LookupResult (PolicyDecl QSym)
lookupPolicy ms mn qs = lookupQSym ms policySyms mn qs

lookupGroup :: ModSymbols -> ModName -> QSym
            -> LookupResult (GroupDecl [ISA] QSym)
lookupGroup ms mn qs = lookupQSym ms groupSyms mn qs

-- Use these functions when you are sure the thing you are looking for exists
-- andthe symbol has the correct type.
-- If it doesn't we call error with a message to terminate the program
getType :: ModSymbols -> ModName -> QSym -> (ModName, TypeDecl QSym)
getType ms mn qs = mayErr "Failed Type Lookup" $ lookupQSym ms typeSyms mn qs

getTag :: ModSymbols -> ModName -> QSym -> (ModName, TagDecl QSym)
getTag ms mn qs = mayErr "Failed Tag Lookup" $ lookupQSym ms tagSyms mn qs

getPolicy :: ModSymbols -> ModName -> QSym -> (ModName, PolicyDecl QSym)
getPolicy ms mn qs =
  mayErr "Failed Policy Lookup" $ lookupQSym ms policySyms mn qs

getGroup :: ModSymbols -> ModName -> QSym -> (ModName, GroupDecl [ISA] QSym)
getGroup ms mn qs = mayErr "Failed Group Lookup" $ lookupQSym ms groupSyms mn qs

-- Use these Fns to filter the list of UsedSymbols down to a particular type
-- e.g. Tags, Types, Groups, Policies
usedTypes :: ModSymbols -> UsedSymbols -> [(ModName, TypeDecl QSym)]
usedTypes ms us = concatMap typeInfo us
  where
    typeInfo :: (ModName, QSym) -> [(ModName, TypeDecl QSym)]
    typeInfo (mn, qt@(QType _)) = [getType ms mn qt]
    typeInfo _ = []

usedTags :: ModSymbols -> UsedSymbols -> [(ModName, TagDecl QSym)]
usedTags ms us = concatMap tagInfo us
  where
    tagInfo :: (ModName, QSym) -> [(ModName, TagDecl QSym)]
    tagInfo (mn, qt@(QTag _)) = [getTag ms mn qt]
    tagInfo _ = []

usedGroups :: ModSymbols -> UsedSymbols -> [(ModName, GroupDecl [ISA] QSym)]
usedGroups ms us = concatMap groupInfo us
  where
    groupInfo :: (ModName, QSym) -> [(ModName, GroupDecl [ISA] QSym)]
    groupInfo (mn, qt@(QGroup _)) = [getGroup ms mn qt]
    groupInfo _ = []

usedRequires :: ModSymbols -> UsedSymbols -> [(ModName, RequireDecl QSym)]
usedRequires ms us = concatMap reqs mods
  where
    mods :: [ModName]
    mods = nub $ sort $ map fst us
    reqs mn =
      case lookup mn ms of
        Nothing -> []
        Just st -> zip (repeat mn) (requires st)

resolveQSym :: ModSymbols -> ModName -> QSym -> QSym
resolveQSym ms startMod qs = qualifyQSym (moduleForQSym ms startMod qs) qs

-- Lookup a qsym to find the module its declared in
moduleForQSym :: ModSymbols -> ModName -> QSym -> ModName
moduleForQSym ms mn qs@(QType _) =
  fst $ mayErr "Failed module lookup" $ lookupQSym ms typeSyms mn qs
moduleForQSym ms mn qs@(QTag _) =
  fst $ mayErr "Failed module lookup" $ lookupQSym ms tagSyms mn qs
moduleForQSym ms mn qs@(QPolicy _) =
  fst $ mayErr "Failed module lookup" $ lookupQSym ms policySyms mn qs
moduleForQSym ms mn qs@(QGroup _) =
  fst $ mayErr "Failed module lookup" $ lookupQSym ms groupSyms mn qs
moduleForQSym _  mn (QVar _) = mn

-- Internal helper functions....
  -- look up a qsym by finding the ST for its module and then using fn to select which Syms to lu
lookupQSym ::
     Eq a
  => ModSymbols
  -> (SymbolTable QSym -> [(QSym, a)])
  -> ModName
  -> QSym
  -> LookupResult a
lookupQSym sts fn mn qs
  | isQualified qs =
    case lookup (modName qs) $ catMaybes $ lookupMod sts fn qs mn of
      Nothing -> Left $ "Unable to find " ++ (qualSymStr qs)
      Just a -> Right (modName qs, a)
lookupQSym sts fn mn qs =
  case nub $ catMaybes $ lookupMod sts fn qs mn of
    [] ->
      Left $
      "Unable to find symbol " ++
      (unqualSymStr qs) ++
      " in modules: " ++
      (intercalate ", " $ map (dotName . fst) sts) ++
      " reached from: " ++ (dotName mn)
    res:[] -> Right res
    reses ->
      Left $
           "Multiple definitions found for symbol \"" ++ (unqualSymStr qs)
        ++ "\".  It is defined in modules:\n  "
        ++ (intercalate ",\n  " $ map (dotName . fst) reses)

type PartialResult a = Maybe (ModName, a)

lookupMod ::
     ModSymbols
  -> (SymbolTable QSym -> [(QSym, a)])
  -> QSym
  -> ModName
  -> [PartialResult a]
lookupMod sts fn qs mn =
  case lookup mn sts of
    Nothing -> []
    Just st -> lookupSym sts st fn mn qs

  -- look up a qsym in a module using fn to select which type of Syms to lu
lookupSym ::
     ModSymbols
  -> SymbolTable QSym
  -> (SymbolTable QSym -> [(QSym, a)])
  -> ModName
  -> QSym
  -> [PartialResult a]
lookupSym sts st fn mn qs =
  case lookup qs $ fn st of
    Nothing -> importedSyms fn
    Just a -> [Just (mn, a)] ++ importedSyms fn
  where
    imports :: [ModName]
    imports = importSyms st
    importedSyms :: (SymbolTable QSym -> [(QSym, a)]) -> [PartialResult a]
    importedSyms stf = concatMap (lookupMod sts stf qs) imports

-- This computes all the tags declared in the "tags" section of a module.  In
-- the future world where we allow modules to examine but not modify tags from
-- other modules, it will include tags that the present module can't modify.
moduleTags :: ModSymbols -> UsedSymbols -> ModName -> [TagDecl QSym]
moduleTags ms allSyms mn = map toTagDecl $ filter byTagDecl allSyms
  where
    byTagDecl :: (ModName, QSym) -> Bool
    byTagDecl (mn', QTag _)
      | mn == mn' = True
    byTagDecl _ = False
    toTagDecl :: (ModName, QSym) -> TagDecl QSym
    toTagDecl (modN, qs) = snd $ getTag ms modN qs

-- create the set of symbol tables for an include graph
symbolTables :: [ModuleDecl QSym] -> Either [ErrMsg] ModSymbols
symbolTables mods = Right $ fmap symbolTable mods

-- create symbol table for a module
symbolTable :: ModuleDecl QSym -> (ModName, SymbolTable QSym)
symbolTable m@(ModuleDecl _ mn sects) = (mn, mkST)
  where
    mkST =
      SymbolTable
        { modDecl = m
        , importSyms = map importDeclName (concatMap importS sects)
        , typeSyms = map (declareSym mn) (concatMap typeS sects)
        , tagSyms = map (declareSym mn) (concatMap tagS sects)
        , policySyms = map (declareSym mn) (concatMap policieS sects)
        , groupSyms = map (declareSym mn) (concatMap groupS sects)
        , requires = (concatMap requireS sects)
        }

    importDeclName :: ImportDecl a -> ModName
    importDeclName (ImportDecl _ dnm) = dnm

    declareSym :: Symbol s => ModName -> s -> (QSym, s)
    declareSym _ s = (unqualQSym $ qsym s, s)
