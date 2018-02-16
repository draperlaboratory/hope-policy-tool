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
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DataKinds #-}
module Symbols where

import Data.Maybe
import Data.Either

import AST
import CommonFn
import ErrorMsg

data SymbolTable n = SymbolTable  { modDecl       :: ModuleDecl QSym
                                  , importSyms    :: [ModName]
                                  , typeSyms      :: [(QSym, TypeDecl n)]
                                  , tagSyms       :: [(QSym, TagDecl n)]
                                  , policySyms    :: [(QSym, PolicyDecl n)]
                                  , groupSyms     :: [(QSym, GroupDecl [ISA] n)]
                                  , requires      :: [RequireDecl n]
                                  }
  deriving Show

type ModSymbols = [(ModName, SymbolTable QSym)]

allQSym :: Foldable f => f QSym -> [QSym]
allQSym = foldr (:) []

lookupPolicy :: ModSymbols -> QSym -> Maybe (PolicyDecl QSym)
lookupPolicy ms x = lookupQSym ms policySyms x

lookupType :: ModSymbols -> QSym -> Maybe (TypeDecl QSym)
lookupType ms x = lookupQSym ms typeSyms x

  -- look up a qsym by finding the ST for its module and then using fn to select which Syms to lu
lookupQSym :: ModSymbols -> (SymbolTable QSym -> [(QSym,a)]) -> QSym -> Maybe a
lookupQSym st fn qs = lookupSym st fn qs mn
  where
    mn = modName qs

-- Returns all type declarations
allTypes :: ModSymbols -> [TypeDecl QSym]
allTypes ms = concatMap (\(_,st) -> map snd $ typeSyms st) ms

-- This computes all the tags declared in the "tags" section of a module.  In
-- the future world where we allow modules to examine but not modify tags from
-- other modules, it will include tags that the present module can't modify.
moduleTags :: ModSymbols -> ModName -> [TagDecl QSym]
moduleTags ms mn =
  case lookup mn ms of
    Nothing -> error $ "Unknown module name " ++ show mn
    Just st -> map snd $ tagSyms st

allTags :: ModSymbols -> [TagDecl QSym]
allTags ms = map snd tags
  where
    tags = concatMap (tagSyms . snd) ms
    
-- look up a qsym in a module using fn to select which Syms to lu
lookupSym :: ModSymbols -> (SymbolTable  QSym -> [(QSym,a)]) -> QSym -> ModName -> Maybe a
--lookupSym sts fn qpn mn | trace ("lu: " ++ (dotName mn) ++ (show qpn) ++ " : " ++ (tmp $ lookup mn sts)) True = lookup mn sts >>= lookup pn . fn
lookupSym sts fn qpn mn = lookup mn sts >>= lookup pn . fn
  where
    pn = unqualQSym qpn
  
-- create the set of symbol tables for an include graph
symbolTables :: [ModuleDecl QSym] -> Either [ErrMsg] ModSymbols
symbolTables mods = Right $ fmap symbolTable mods

-- create symbol table for a module
symbolTable :: ModuleDecl QSym -> (ModName, SymbolTable QSym)
symbolTable m@(ModuleDecl _ mn sects) = (mn, mkST)
  where
    mkST = SymbolTable { modDecl       = m
                       , importSyms    = map importDeclName (sect importS sects)
                       , typeSyms      = map (declareSym mn) (sect typeS sects)
                       , tagSyms       = map (declareSym mn) (sect tagS sects)
                       , policySyms    = map (declareSym mn) (sect policieS sects)
                       , groupSyms     = map (declareSym mn) (sect groupS sects)
                       , requires       = (sect requireS sects)
                       }
    declareSym :: Symbol s => ModName -> s -> (QSym, s)
    declareSym _ s = (unqualQSym $ qsym s, s)
    

-- check if the symbol table has errors
symbolTableErrors :: SymbolTable ErrQSym -> [ErrMsg]
symbolTableErrors = lefts . extractST

rightST :: (ModName, SymbolTable ErrQSym) -> (ModName, SymbolTable QSym)
rightST (mn,st) = (mn, st')
  where
    st'  = st { typeSyms      = map rightSym $ typeSyms st
              , tagSyms       = map rightSym $ tagSyms st
              , policySyms    = map rightSym $ policySyms st
              , groupSyms     = map rightSym $ groupSyms st
              , requires         = map rightInit $ requires st 
              }
    rightInit = fmap toRight
    rightSym (s, t) = (s, fmap toRight t)
    toRight (Right qn) = qn
    toRight (Left _) = unexpectedError

  
extractST :: SymbolTable ErrQSym -> [ErrQSym]
extractST st = (getErrs $ tagSyms st) ++
                  (getErrs $ policySyms st) ++
                  (getErrs $ groupSyms st) ++
                  (reqErrs $ requires st)
  where
    getErrs :: Foldable f => [(a, f (Either b b1))] -> [(Either b b1)]
    getErrs  = concatMap (foldr (:) [] . snd)
    reqErrs :: Foldable f => [f (Either b b1)] -> [(Either b b1)]
    reqErrs  = concatMap (foldr (:) [])
  
qualifyAllST :: ModSymbols -> Either [ErrMsg] [(ModName, SymbolTable ErrQSym)]
qualifyAllST sts = Right $ map (qualifyST sts) sts

-- qualify all the symbols in the symbol table entries
qualifyST :: ModSymbols -> (ModName, SymbolTable QSym) -> (ModName, SymbolTable ErrQSym)
qualifyST sts (mn,st) = (mn, st')
  where
    st'  = st { typeSyms      = map qualSym $ typeSyms st
              , tagSyms       = map qualSym $ tagSyms st
              , policySyms    = map qualSym $ policySyms st
              , groupSyms     = map qualSym $ groupSyms st
              , requires      = map qualInit $ requires st 
              }
    qualSym (s, t) = (s, fmap (qualifySym sts) t)
    qualInit t = fmap (qualifySym sts) t

-- figure out the module where a sym is declared and qualify the sym with
--  the module name. Symbols that are explicitly qualified are checked to be valid
--  and passed along unchanged. Syms that have multiple declarations are errors.
--  Variables don't get qualified.
qualifySym :: ModSymbols -> QSym -> Either ErrMsg QSym
-- don't qualify vars
qualifySym _ qs@(QVar _) = Right qs
-- handle case for explicit qualified symbol
qualifySym sts qs | isQualified qs =
                        let mn = modName qs in
                        case lookup mn sts of
                          Just st -> case resolveSym qs st of
                            Just sym -> Right $ qualifyName mn $ sym
                            Nothing -> Left $ "Symbol " ++ (unqualSymStr qs) ++ " not in module " ++ (dotName mn)
                          Nothing -> Left $ "Unknown module " ++ (dotName mn)
-- look up unqual symbol hoping to find only 1 match                          
qualifySym sts qs = unique matches
  where
    mods = map fst sts
    maybeMatch = map (resolveSym qs . snd) sts
    matches = map unjust $ filter (isJust.snd) $ zip mods maybeMatch
    unique [] = Left $ "Unknown name: " ++ (unqualSymStr qs)
    unique ((mn,sym):[]) = Right $ qualifyName mn sym
    unique syms = Left $ "multiple matches for " ++ (unqualSymStr qs) ++ ", found in: " ++ (mkComma $  map (dotName.fst) syms)

----------------------------------------------   helpers       --------------------------------------------

-- Check AST for errors and return either errors or AST with Right removed
symErrors :: (Functor f, Foldable f) => f (Either a b) -> Either [a] (f b)
symErrors sym = case foldr errs [] sym of
  [] -> Right $ fmap toRight sym
  es -> Left es
  where errs (Left a) acc = a:acc
        errs _ acc = acc
        toRight (Right qn) = qn
        toRight (Left _) = codingError "Unexpected error"

nolu :: QSym -> SymbolTable QSym -> Maybe QSym
nolu qs _ = Just qs

resolveImports :: ModSymbols -> [(ModName, ModSymbols)]
resolveImports sts = zip mods $ map result imps
  where
    mods = map fst sts
    imps = map (importSyms . snd) sts
    result imp = map unjust $ filter (isJust.snd) $ zip mods $ map (find sts) imp
    find st sym = lookup sym st


resolveSym :: QSym -> SymbolTable QSym -> Maybe QSym
resolveSym qs@(QType _)  = lookup qs . map toSym . typeSyms
resolveSym qs@(QTag _)  = lookup qs . map toSym . tagSyms
resolveSym qs@(QVar _)  = nolu qs
resolveSym qs@(QPolicy _)   = lookup qs . map toSym . policySyms  
resolveSym qs@(QGroup _)   = lookup qs . map toSym . groupSyms

toSym :: forall t n. Symbol n => (t, n) -> (t, QSym)
toSym (a,b) = (a, qsym b)

unjust :: forall t t1. (t, Maybe t1) -> (t, t1)
unjust (a, Just b) = (a,b)
unjust _ = codingError "Unexpected Nothing"

qualifyName :: ModName -> QSym -> QSym
qualifyName mn qs = fmap (mn ++) qs
