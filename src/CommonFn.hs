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
module CommonFn
  (importS, typeS, tagS, policieS, groupS, requireS,
   qualifyQSym, groupPrefix, modName, unqualQSym,
   dotName, typeName, tagName, tagString,
   policyDotName, moduleDotName, unqualSymStr, qualSymStr,
   isQualified,
   tab, hex, dash)
where

import Data.List (init,intercalate)
import Data.Char (toLower)

import Numeric

import AST

{-
 -  Accessors for portions of a module.
 -}
importS :: SectDecl t -> [ImportDecl t]
importS (Imports s) = s
importS _ = []

typeS :: SectDecl t -> [TypeDecl t]
typeS (Types s) = s
typeS _ = []

tagS :: SectDecl t -> [TagDecl t]
tagS (Tags s) = s
tagS _ = []

policieS :: SectDecl t -> [PolicyDecl t]
policieS (Policies s) = s
policieS _ = []

groupS :: SectDecl t -> [GroupDecl [ISA] t]
groupS (Groups s) = s
groupS _ = []

requireS :: SectDecl t -> [RequireDecl t]
requireS (Require s) = s
requireS _ = []

{-
 - Constructing QSyms
 -}
qualifyQSym :: ModName -> QSym -> QSym
qualifyQSym mn qs = fmap (mn++) qs

groupPrefix :: QSym -> QSym
groupPrefix  = fmap ("og":)

modName :: QSym -> ModName
modName = init . qName

unqualQSym :: QSym -> QSym
unqualQSym = fmap (\nms -> [last nms])

{-
 - Printing QSyms
 -}
qName :: QName t -> t
qName (QType ns) = ns
qName (QTag ns) = ns
qName (QVar ns) = ns
qName (QPolicy ns) = ns
qName (QGroup ns) = ns

dotName :: [[Char]] -> [Char]
dotName = intercalate "."

typeName :: QSym -> String
typeName = reqName . map toLower . intercalate "_" . qName

tagName :: QSym -> String
tagName = reqName . intercalate "_" . qName

tagString :: QSym -> String
tagString = dotName . qName

reqName :: String -> String
reqName n = map rep n
  where
    rep '/' = '_'
    rep '-' = '_'
    rep c = c

policyDotName :: PolicyDecl QSym -> String
policyDotName = dotName . qName . qsym

moduleDotName :: ModuleDecl t -> [Char]
moduleDotName (ModuleDecl _ mn _) = dotName mn

unqualSymStr :: QSym -> String
unqualSymStr qSym = last $ qName qSym

qualSymStr :: QSym -> String
qualSymStr qSym = dotName $ qName qSym

{-
 - Analyzing qsyms
 -}
isQualified :: QSym -> Bool
isQualified qs = length (qName qs) /= 1

{-
 - Other printing stuff
 -}
tab :: Int -> [Char]
tab n = replicate (n*4) ' '

hex :: (Show n, Integral n) => n -> String
hex n = "0x" ++ (showHex n) ""

dash :: String
dash = replicate 32 '-'
