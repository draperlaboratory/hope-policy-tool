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
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveFunctor #-}
module AST where

import ErrorMsg

type Name = String
type ModName = [String]
type PolicyName = [String]
type Inst = String
type Incr = Bool
type QSym = QName [String]
type ErrQSym = Either ErrMsg QSym

data SrcPos = SP !String !Int !Int  -- filename, line, column
  deriving (Eq,Show,Ord)

ppSrcPos :: SrcPos -> String
ppSrcPos (SP f l c) = f ++ ":" ++ show l ++ ":" ++ show c

---------------------------------------------   Symbols   --------------------------------------------
data QName n = QVar n | QTag n | QPolicy n | QGroup n | QType n
  deriving (Show, Eq, Ord, Functor, Foldable)

class Symbol n where
  qsym :: n -> QSym
  pos :: n -> SrcPos
  
---------------------------------------------   Module    --------------------------------------------
data ModuleDecl n = ModuleDecl SrcPos ModName [SectDecl n]
  deriving (Show, Eq, Functor, Foldable)

---------------------------------------------   Import     --------------------------------------------
data ImportDecl n = ImportDecl SrcPos ModName
  deriving (Show, Eq, Functor, Foldable)

---------------------------------------------   Sections    --------------------------------------------
data SectDecl n = Imports [ImportDecl n]
                | Types [TypeDecl n]
                | Tags [TagDecl n]
                | Policies [PolicyDecl n]
                | Groups [GroupDecl [ISA] n]
                | Require [RequireDecl n]
                deriving (Eq, Show, Functor, Foldable)

----------------------------------------------   Type       --------------------------------------------

data TypeDecl n = TypeDecl SrcPos n TagDataType
  deriving (Show, Eq, Ord, Functor, Foldable)

instance Symbol (TypeDecl QSym) where
  qsym (TypeDecl _ qn _) = qn
  pos (TypeDecl p _ _) = p

data TagDataType = TDTInt SrcPos (Maybe Int)
  deriving (Show,Eq,Ord)


----------------------------------------------   Tag        --------------------------------------------
data TagDecl n = TagDecl SrcPos n [n]
  deriving (Show, Eq, Ord, Functor, Foldable)


data Tag n = Tag SrcPos n [TagField n]
  deriving (Show, Eq, Ord, Functor, Foldable)

instance Symbol (Tag QSym) where
  qsym (Tag _ qn _) = qn
  pos  (Tag p _ _) = p


data TagField n = TFVar SrcPos n
                | TFNew SrcPos
                | TFAny SrcPos
                | TFInt SrcPos Int
                | TFBinOp SrcPos TagFieldBinOp (TagField n) (TagField n)
  deriving (Show, Eq, Ord, Functor, Foldable)

data TagFieldBinOp = TFBOPlus
                   | TFBOMinus
                   | TFBOTimes
                   | TFBODiv
                   | TFBOMod
  deriving (Show, Eq, Ord)

---------------------------------------------   Set        --------------------------------------------

data TagSetPat n = TSPAny SrcPos
                 | TSPExact SrcPos [Tag n]
                 | TSPAtLeast SrcPos [TagEx n]
  deriving (Show, Eq, Functor, Foldable)

data TagSetEx n = TSEVar  SrcPos n
                | TSEExact SrcPos [Tag n]
                | TSEModify SrcPos (TagSetEx n) [TagEx n]
                | TSEUnion SrcPos (TagSetEx n) (TagSetEx n)
                | TSEIntersect SrcPos (TagSetEx n) (TagSetEx n)
  deriving (Show, Eq, Functor, Foldable)


instance Symbol (TagDecl QSym) where
  qsym (TagDecl _ qn _) = qn
  pos  (TagDecl p _ _) = p

data TagEx n = TagEx SrcPos (Tag n)
             | TagPlusEx SrcPos (Tag n)
             | TagMinusEx SrcPos (Tag n)
  deriving (Show, Eq, Functor, Foldable)
                
---------------------------------------------   Policy     --------------------------------------------
data PolicyLocality = PLLocal | PLGlobal
  deriving (Show, Eq)

data PolicyDecl n = PolicyDecl SrcPos PolicyLocality n (PolicyEx n)
  deriving (Show, Eq, Functor, Foldable)
           
instance Symbol (PolicyDecl QSym) where
  qsym (PolicyDecl _ _ qn _) = qn
  pos  (PolicyDecl p _ _ _) = p

data RuleClause n = RuleClause SrcPos n [BoundGroupPat n] (RuleResult n)
  deriving (Show, Eq, Functor, Foldable)

data BoundGroupPat n = BoundGroupPat SrcPos n (TagSetPat n)
  deriving (Show, Eq, Functor, Foldable)

data RuleResult n = RRFail SrcPos String
                  | RRUpdate SrcPos [BoundGroupEx n]
  deriving (Show, Eq, Functor, Foldable)

data BoundGroupEx n = BoundGroupEx SrcPos n (TagSetEx n)
  deriving (Show, Eq, Functor, Foldable)

data PolicyEx n = PEVar SrcPos n
                | PECompExclusive SrcPos (PolicyEx n) (PolicyEx n)
                | PECompPriority SrcPos (PolicyEx n) (PolicyEx n)
                | PECompModule SrcPos (PolicyEx n) (PolicyEx n)
                | PERule SrcPos (RuleClause n)
                | PENoChecks SrcPos
  deriving (Show, Eq, Functor, Foldable)

---------------------------------------------    Requires      --------------------------------------------

data RequireDecl n = Init SrcPos [String] (InitSet n)
  deriving (Show, Eq, Functor, Foldable)

data InitSet n = ISExact SrcPos [Tag n]
  deriving (Show, Eq, Functor, Foldable)
           

---------------------------------------------   Group      --------------------------------------------
data GroupDecl a n = GroupDecl SrcPos n [GroupParam n] [GroupParam n] a
  deriving (Show, Eq, Functor, Foldable)

instance Symbol (GroupDecl a QSym) where
  qsym (GroupDecl _ qn _ _ _) = qn
  pos  (GroupDecl p _ _ _ _) = p

data GroupParam n = GroupParam SrcPos TagSpec n
  deriving (Show, Eq, Functor, Foldable)

data ISA = Asm SrcPos Inst (Maybe [OpSpec])
  deriving (Show, Eq)

data TagSpec = RD | RS1 | RS2 | RS3 | Csr | Mem
  deriving (Show, Eq, Ord)

data RF =
    X0
  | X1
  | X2
  | X3
  | X4
  | X5
  | X6
  | X7
  | X8
  | X9
  | X10
  | X11
  | X12
  | X13
  | X14
  | X15
  | X16
  | X17
  | X18
  | X19
  | X20
  | X21
  | X22
  | X23
  | X24
  | X25
  | X26
  | X27
  | X28
  | X29
  | X30
  | X31
  deriving (Eq, Ord, Show, Enum)
           
data OpSpec =   
    AnyOp
  | Const Integer
  | Reg RF
    deriving (Eq, Ord, Show)
             
