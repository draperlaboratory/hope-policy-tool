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
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module SrcPrinter where

import Data.List

import AST
import GenUtils
import CommonFn


printModule :: ModuleDecl QSym -> [String]
printModule md@(ModuleDecl _ _ _) = [ "module " ++ (moduleDotName md) ++ ":", ""] -- <:> concatMap printSect sects

printPolicy :: PolicyDecl QSym -> [String]
printPolicy (PolicyDecl _ _ pqn ex) = [fmt 1 (unqualSymStr pqn) ++ " = "] ++ (map (fmt 2) (printPolicyEx ex))

printPolicyEx :: PolicyEx QSym -> [String]
printPolicyEx (PERule _ clause) = [printRuleClause clause]
printPolicyEx (PECompExclusive _ lhs rhs) = printPolicyEx lhs ++ ["]["] ++ printPolicyEx rhs
printPolicyEx (PECompPriority _ lhs rhs) = printPolicyEx lhs ++ ["^"] ++ printPolicyEx rhs
printPolicyEx (PECompModule _ lhs rhs) = printPolicyEx lhs ++ ["&"] ++ printPolicyEx rhs
printPolicyEx (PEVar _ qn) = [qualSymStr qn]
printPolicyEx (PENoChecks _) = ["__NO_CHECKS"]

printRuleClause :: RuleClause QSym -> String
printRuleClause (RuleClause _ og pats _) =
  (last $ qName og) ++ "<"
     ++ (intercalate ", " $ map printPat pats) ++ ">"

printPat :: BoundGroupPat QSym -> String
printPat (BoundGroupPat _ nm tsp) =
  (last $ qName nm) ++ "=" ++ printTagSetPat tsp

printTagSetPat :: TagSetPat QSym -> String
printTagSetPat (TSPAny _) = "_"
--printTagSetPat (TSPVar _ nm) = last $ qName nm
printTagSetPat (TSPExact _ tgs) =
  "{" ++ (intercalate ", " $ map printTag tgs) ++ "}"
printTagSetPat (TSPAtLeast _ tes) = 
  "{" ++ (intercalate ", " $ map printTagEx tes) ++ "}"
--printTagSetPat (TSPVarSet _ nm tsp) = (last $ qName nm) ++ "@" ++ printTagSetPat tsp
  
printTag :: Tag QSym -> String
printTag (Tag _ nm args) =
  intercalate " " $ (last $ qName nm) : map printTagField args

printTagField :: TagField QSym -> String
printTagField (TFVar _ n) = last $ qName n
printTagField (TFNew _) = "new"
printTagField (TFAny _) = "_"
printTagField (TFInt _ i) = show i
printTagField (TFBinOp _ b tf1 tf2) =
     "(" ++ printTagField tf1 ++ " " ++ printTagFieldBinOp b
  ++ " " ++ printTagField tf2 ++ ")"

printTagFieldBinOp :: TagFieldBinOp -> String
printTagFieldBinOp TFBOPlus  = "+"
printTagFieldBinOp TFBOMinus = "-"
printTagFieldBinOp TFBOTimes = "*"
printTagFieldBinOp TFBODiv   = "/"
printTagFieldBinOp TFBOMod   = "%"

printTagEx :: TagEx QSym -> String
printTagEx (TagEx _ t) = printTag t
printTagEx (TagPlusEx _ t) = "+" ++ printTag t
printTagEx (TagMinusEx _ t) = "-" ++ printTag t
