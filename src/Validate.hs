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
module Validate where



import AST

import CommonFn
import Symbols
import ErrorMsg


validateModules :: Either [ErrMsg] [ModuleDecl QSym] -> Either [ErrMsg] [(ModName, SymbolTable QSym)]
validateModules mods = mods >>= symbolTables >>= qualifyAllST >>= validateSymbolTables

validateSymbolTables :: [(ModName, SymbolTable ErrQSym)] -> Either [ErrMsg] [(ModName, SymbolTable QSym)]
validateSymbolTables sts = case concatMap (symbolTableErrors.snd) sts of
  [] -> Right $ map rightST sts
  errs -> Left errs
  
validateMain :: [String] -> [(ModName, SymbolTable QSym)] -> Either [ErrMsg] (Maybe (PolicyDecl QSym))
validateMain [] _ = Right Nothing
validateMain (mainPolicy:[]) sts =
  case lookupQSym sts policySyms policyQSym of
    Nothing -> Left ["Can't find policy " ++ mainPolicyName ++ " in " ++ mainModName]
    mpol -> Right mpol
  where
    policyQSym = QPolicy $ parseDotName mainPolicy
    mainModName = modSymStr policyQSym
    mainPolicyName = unqualSymStr policyQSym
validateMain _ _ = Left ["Bad main policy name"]


validatePolicy :: Functor f => [(ModName, SymbolTable QSym)] -> f QSym -> f (Either ErrMsg QSym)
validatePolicy sts pol = fmap (qualifySym sts) pol



elabPolicy :: [(ModName, SymbolTable QSym)] -> Maybe (PolicyDecl QSym) -> Maybe (PolicyDecl QSym)
elabPolicy _ Nothing = Nothing
elabPolicy st (Just (PolicyDecl p pl pqn ex)) = Just $ PolicyDecl p pl pqn $ elabPEx ex
  where
    elabPEx :: PolicyEx QSym -> PolicyEx QSym
    elabPEx (PERule sp clause) = PERule sp clause
    elabPEx (PECompModule sp lhs rhs)    = PECompModule sp (elabPEx lhs) (elabPEx rhs)
    elabPEx (PECompExclusive sp lhs rhs) = PECompExclusive sp (elabPEx lhs) (elabPEx rhs)
    elabPEx (PECompPriority sp lhs rhs)  = PECompPriority sp (elabPEx lhs) (elabPEx rhs)
    elabPEx (PEVar _ qn) =
      case lookupQSym st policySyms qn of
        (Just (PolicyDecl _ _ _ rex)) -> elabPEx rex
        _ -> codingError $ "Failed to resolve validated policy: " ++ (qualSymStr qn)
