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
{-# LANGUAGE NamedFieldPuns #-}
module Validate (locateTopLevelPolicies,
                 validateMain, validateModuleRequires,
                 nubSymbols,
                 TopLevelPolicies(..)) where

import Data.Either (lefts, rights, partitionEithers)
import Data.List (nub, sort, partition)

import AST
import Symbols
import CommonFn (modName,dotName,unqualQSym)
import ErrorMsg (ErrMsg,codingError)
import PolicyParser (parseDotName)

-- Validate module: Perform error checking on policies and DPL modules.
-- Eventually will include type checking, currently only handles resolving
-- symbol references.

-- This describes the collection of individual policies being composed.
data TopLevelPolicies =
  TopLevelPolicies {tlpGlobals :: [(ModName,PolicyDecl QSym)],
                    tlpLocals  :: [(ModName,PolicyDecl QSym)]}

-- This idenfies the top-level policies that are being composed together,
-- which might be one or many.  The user can pass multiple policy names at the
-- command line, and each of those may be a composition of several policies
-- with the "&" operator.  We used to demand that global policies are listed
-- first, but no longer do.
--
-- Specifically: This looks at the definition of every policy named at the
-- command line.  For each, either its definition is some nested policy names
-- composed with &, in which case those are treated as top-level policies, or
-- if not the named policy is a top-level policy.  Then we group the top-level
-- policies into global and local.
locateTopLevelPolicies :: [String] -> ModSymbols
                       -> Either [ErrMsg] TopLevelPolicies
locateTopLevelPolicies [] _ = codingError "No policy case should be handled"
locateTopLevelPolicies cmdLineNames modSyms =
  case partitionEithers (map getPieces policyQSyms) of
    ([],unsortedPols) ->
      case separateGlobals $ concat unsortedPols of
        (_,[]) ->
          Left ["No policy or only global polcies provided on command line.\n"]
        (gs,ls) ->
          Right $ TopLevelPolicies {tlpGlobals = gs, tlpLocals = ls}
    (errs,_) -> Left errs
  where
    policyQSyms :: [QSym]
    policyQSyms = map (QPolicy . parseDotName) cmdLineNames

    getPieces :: QSym -> Either ErrMsg [(ModName,PolicyDecl QSym)]
    getPieces pqsym = do
      (pmod,pdecl) <- lookupPolicy modSyms modNm polNm
      topPolicyPieces modSyms pmod pdecl
      where
        modNm :: ModName
        modNm = modName pqsym
        polNm :: QSym
        polNm = unqualQSym pqsym

    separateGlobals :: [(a,PolicyDecl QSym)]
                    -> ([(a,PolicyDecl QSym)],[(a,PolicyDecl QSym)])
    separateGlobals =
      partition (\(_,PolicyDecl _ l _ _) -> l == PLGlobal)


-- This does the work of breaking apart the definitions of the policies
-- provided on the command line.  We check to see of the definition of each
-- command-line policy has the form:
--
--      p_1 & ... & p_n
--
-- In which case we break it apart into a list.  As a special case, if the
-- policy does not have this form it is treated as if n = 1.
topPolicyPieces :: ModSymbols -> ModName -> PolicyDecl QSym
                -> Either ErrMsg [(ModName, PolicyDecl QSym)]
topPolicyPieces ms topMod topDecl = topLevelDeclsD topMod topDecl
  where
    -- Computes the names of the policies composed with &s, in order
    topLevelDeclsD :: ModName -> PolicyDecl QSym
                   -> Either ErrMsg [(ModName,PolicyDecl QSym)]
    topLevelDeclsD mn (PolicyDecl _ _ _ pe@(PECompModule _ _ _)) =
      topLevelDeclsE mn pe
    topLevelDeclsD mn (PolicyDecl _ _ _ pe@(PEVar _ _)) =
      topLevelDeclsE mn pe
    topLevelDeclsD mn p = Right [(mn,p)]

    topLevelDeclsE :: ModName -> PolicyEx QSym
                   -> Either ErrMsg [(ModName,PolicyDecl QSym)]
    topLevelDeclsE _ (PEVar _ x) =
      let (mn',p') = getPolicy ms topMod x in topLevelDeclsD mn' p'
    topLevelDeclsE mn (PECompModule _ p1 p2) = do
      ds1 <- topLevelDeclsE mn p1
      ds2 <- topLevelDeclsE mn p2
      Right $ ds1 ++ ds2
    topLevelDeclsE _ _ = Left tppError

    tppError :: String
    tppError = "Error: top-level policies must have the form:\n\n"
            ++ "   p_1 & ... & p_n\n\n"
            ++ "Where each p_i is a policy name.\n"

-- Validate that all symbols are reachable from the top level policies.
-- Starts from main policy decl and traverses the ast looking up each symbol
-- in the ModSymbols and records errors or builds UsedSymbols list.
--
-- CJC XXX : I have fixed some glaring efficiency bugs in this code, but it
-- could still be a lot faster.  In particular we should maintain a set of
-- UsedSymbols rather than a list that we nub and sort at the end.
validateMain :: ModSymbols -> TopLevelPolicies
             -> Either [ErrMsg] UsedSymbols
validateMain ms (TopLevelPolicies {tlpGlobals,tlpLocals}) =
  if null errors then Right (nubSymbols symbols)
                 else Left errors
  where
    errors :: [ErrMsg]
    symbols :: [(ModName, QSym)]
    (errors,symbols) =
      foldr (\(mod,pol) acc -> validatePolicyDecl ms mod pol acc)
            ([],[])
            (tlpGlobals ++ tlpLocals)

-- Helper Fns to do validation...
validatePolicyDecl :: ModSymbols -> ModName -> PolicyDecl QSym
                   -> ([ErrMsg],[(ModName, QSym)])
                   -> ([ErrMsg],[(ModName, QSym)])
validatePolicyDecl ms mn pd@(PolicyDecl _ _ _ pex) (accE,accS) =
  validatePolicyEx ms mn pex (accE,(mn, qsym pd):accS)

validatePolicyEx :: ModSymbols -> ModName -> PolicyEx QSym
                 -> ([ErrMsg],[(ModName, QSym)])
                 -> ([ErrMsg],[(ModName, QSym)])
validatePolicyEx ms mn (PEVar _ x) acc@(accE,accS) =
  case lookupPolicy ms mn x of
    Right (mn', pd) -> validatePolicyDecl ms mn' pd acc
    Left err -> (err:accE,accS)
validatePolicyEx ms mn (PECompExclusive _ p1 p2) acc =
    validatePolicyEx ms mn p1 $ validatePolicyEx ms mn p2 acc
validatePolicyEx ms mn (PECompPriority _ p1 p2) acc =
  validatePolicyEx ms mn p1 $ validatePolicyEx ms mn p2 acc
validatePolicyEx ms mn (PECompModule _ p1 p2) acc =
  validatePolicyEx ms mn p1 $ validatePolicyEx ms mn p2 acc
validatePolicyEx ms mn rule acc = foldr (validateQSym ms mn) acc rule

validateModuleRequires :: ModSymbols -> [ModName]
                       -> Either [ErrMsg] [(ModName, QSym)]
validateModuleRequires ms mns =
  case validationResults of
    ([],syms) -> Right $ nubSymbols syms
    (errs,_) -> Left errs
  where
    validationResults :: ([ErrMsg],[(ModName, QSym)])
    validationResults = foldr vmr ([],[]) mns
    vmr :: ModName
        -> ([ErrMsg],[(ModName, QSym)])
        -> ([ErrMsg],[(ModName, QSym)])
    vmr mn acc@(accE,accS) =
      case lookup mn ms of
        Nothing -> (("Unable to locate module: " ++ (dotName mn)):accE,
                    accS)
        Just st -> foldr (validateRequires ms mn) acc $ requires st

validateRequires :: ModSymbols -> ModName -> RequireDecl QSym
                 -> ([ErrMsg],[(ModName, QSym)])
                 -> ([ErrMsg],[(ModName, QSym)])
validateRequires ms mn (Init _ _ (ISExact _ ts)) acc = foldr tagLookup acc ts
  where
    tagLookup :: Tag QSym
              -> ([ErrMsg],[(ModName, QSym)])
              -> ([ErrMsg],[(ModName, QSym)])
    tagLookup tgs res = foldr (validateQSym ms mn) res tgs

validateQSym :: ModSymbols -> ModName -> QSym
             -> ([ErrMsg],[(ModName, QSym)])
             -> ([ErrMsg],[(ModName, QSym)])
validateQSym ms mn qs@(QType _) acc = accLookup (lookupType ms mn) qs acc
validateQSym ms mn qs@(QTag _) (accE,accS) =
  case lookupTag ms mn qs of
    Left err -> (err:accE,accS)
    Right (mn',_) -> validateType ms mn' qs (accE, (mn',qs):accS)
validateQSym ms mn qs@(QPolicy _) acc = accLookup (lookupPolicy ms mn) qs acc
validateQSym ms mn qs@(QGroup _) acc = accLookup (lookupGroup ms mn) qs acc
validateQSym _ mn qs (accE,accS) = (accE, (mn, qs):accS)

validateType :: ModSymbols -> ModName -> QSym
             -> ([ErrMsg],[(ModName, QSym)])
             -> ([ErrMsg],[(ModName, QSym)])
validateType ms mn qs acc = foldr (validateQSym ms mn) acc typs
  where
    (_, TagDecl _ _ typs) = getTag ms mn qs

accLookup :: (QSym -> Either ErrMsg (ModName,a)) -> QSym
          -> ([ErrMsg],[(ModName,QSym)])
          -> ([ErrMsg],[(ModName,QSym)])
accLookup fn qs (accE,accS) =
  case fn qs of
    Left err -> (err:accE, accS)
    Right (mn, _) -> (accE, (mn,qs):accS)

nubSymbols :: [(ModName, QSym)] -> [(ModName, QSym)]
nubSymbols = nub . sort . map unqualify
  where
    unqualify (mn, qs) = (mn, unqualQSym qs)
