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
{-# LANGUAGE RankNTypes, NamedFieldPuns #-}
module Tags (setTags,buildTagInfo,usedModules,TagInfo(..)) where

-- -- import CommonTypes
import CommonFn
import AST
import Symbols
import qualified Data.Set as S
import qualified Data.Map as M
import Data.Word
import Data.List (sort,foldl')

-- This struct collects a bunch of info about the tags used by the current
-- policy (and its imports).  It is meant to be computed once and passed around.
--
-- XXX The policy masks should really be put in here and used as needed rather
-- than being defined as C variables.  Not doing this now because this version
-- of the language is unlikely to stick around.
data TagInfo =
  TagInfo {tiMaxTag :: Word32,
           -- The "biggest tag".  That is, the last position in the bitfield
           -- that is used.

           tiNumBitFields :: Word32,
           tiNumDataArgs  :: Word32,
           tiArrayLength    :: Word32,
           -- The number of Word32s used as bitfields and argument holders,
           -- respectively, in the tag struct's array.  The sum of these two
           -- numbers is the size of a tag struct, in words.

           tiTagNames :: [QSym],
           -- All tag names.  The domain of tiTagBitPositions

           tiGroupNames :: [QSym],
           -- All opgroup names.  A subset of tiTagNames.

           tiTagBitPositions :: M.Map QSym Word32,
           -- A map from tag names to the position of the bit that indicates the
           -- tag's presence.

           tiTagArgInfo :: M.Map QSym [(Word32,TypeDecl QSym)]
           -- A map from tag names to array indexes.  If a tag maps to
           -- [(i1,t1),(i2,t2)], then this tag has two data arguments, which are
           -- kept at positions i1 and i2 of the tag array and have types t1 and
           -- t2.
          }
  deriving (Show)

usedModules :: ModSymbols -> Maybe (PolicyDecl QSym) -> S.Set ModName
usedModules _ Nothing = S.empty
usedModules ms (Just pd) = policyDeclModules ms pd

policyDeclModules :: ModSymbols -> PolicyDecl QSym -> S.Set ModName
policyDeclModules ms (PolicyDecl _ _ qs pe) =
  S.insert (modName qs) $ policyExModules ms pe

policyExModules :: ModSymbols -> PolicyEx QSym -> S.Set ModName
policyExModules ms (PEVar _ v) =
  case lookupPolicy ms v of
    Nothing -> error $ "Unknown policy name " ++ show v
    Just p -> policyDeclModules ms p
policyExModules ms (PECompExclusive _ pe1 pe2) =
  S.union (policyExModules ms pe1) (policyExModules ms pe2)
policyExModules ms (PECompPriority _ pe1 pe2) =
  S.union (policyExModules ms pe1) (policyExModules ms pe2)
policyExModules ms (PECompModule _ pe1 pe2) =
  S.union (policyExModules ms pe1) (policyExModules ms pe2)
policyExModules _ (PERule _ (RuleClause _ og _ _ )) =
  S.singleton (modName og)

setTags :: InitSet t -> [Tag t]
setTags (ISExact _ ts) = ts

-- This constructs the tag info.  It assumes the ModSymbols it is passed
-- contains only the relevant modules.  Any tags in the modules it is passed
-- will appear in the generated code.
buildTagInfo :: ModSymbols -> TagInfo
buildTagInfo ms = 
  TagInfo {tiMaxTag,
           tiNumBitFields,
           tiNumDataArgs,
           tiArrayLength = tiNumBitFields + tiNumDataArgs,

           tiTagNames = map qsym declaredTags,
           tiGroupNames = map qsym ogFakeTagDecls,
           tiTagBitPositions = M.fromList $ zip (map qsym declaredTags)
                                                [minTagNumber..],
           tiTagArgInfo = dataArgInfo}
  where
    tiMaxTag,tiNumBitFields,tiNumDataArgs :: Word32
    tiMaxTag = minTagNumber + (fromIntegral $ length declaredTags) - 1
    tiNumBitFields = 1 + (div tiMaxTag 32)
    tiNumDataArgs = fromIntegral $ length $
       concatMap (\(TagDecl _ _ args) -> args) declaredTags
    
    -- This is all the tags that are explicitly declared in modules that this
    -- policy uses bits from, plus fake declarations for the opgroups, since
    -- they are really tags.
    declaredTags :: [TagDecl QSym]
    declaredTags = sort $ actualDecls ++ ogFakeTagDecls
      where
        actualDecls :: [TagDecl QSym]
        actualDecls = map snd $ concatMap (tagSyms . snd) ms

    ogFakeTagDecls :: [TagDecl QSym]
    ogFakeTagDecls = map (makeOGDecl . snd) $ concatMap (groupSyms . snd) ms
      where
        makeOGDecl :: GroupDecl a QSym -> TagDecl QSym
        makeOGDecl (GroupDecl sp nm _ _ _) = TagDecl sp (groupPrefix nm) []
        
--    relevantTags :: [TagDecl QSym]
--    relevantTags = sort $
--      mapMaybe (\tdcl -> if S.member (qsym tdcl) usedTags then Just tdcl else Nothing)
--               declaredTags

    findTypeDef :: QSym -> TypeDecl QSym
    findTypeDef qs =
      case lookupType ms qs of
        Nothing -> error $ "Encountered unknown type name " ++ tagName qs
                        ++ " while building TagInfo data structure."
        Just td -> td

    dataArgInfo :: M.Map QSym [(Word32,TypeDecl QSym)]
    dataArgInfo = fst $ foldl' folder (M.empty,tiNumBitFields) declaredTags
      where
        folder :: (M.Map QSym [(Word32,TypeDecl QSym)], Word32)
               -> TagDecl QSym
               -> (M.Map QSym [(Word32,TypeDecl QSym)], Word32)
        folder (accMap,nextPos) (TagDecl _ nm typs) =
          (M.insert nm (zip [nextPos..] (map findTypeDef typs)) accMap,
           (fromIntegral $ length typs) + nextPos)
        
minTagNumber :: Word32
minTagNumber = 16
