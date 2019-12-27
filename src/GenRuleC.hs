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
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TupleSections #-}
module GenRuleC (writeRuleCFile) where

import Data.Loc           (noLoc)
import Data.List          (foldl',find)
import Data.Word
import Data.Array.Unboxed (elems)
import Data.Bits          ((.|.))
import Data.Maybe         (mapMaybe)
import qualified Data.Map as M
import qualified Data.Array.ST as A
import Control.Monad.ST (ST)

import Language.C.Syntax
import Language.C.Quote.GCC

import AST
import Symbols
import CommonFn
import GenUtils   (renderC)
import Tags       (TagInfo(..))
import SrcPrinter (printRuleClause, printTagFieldBinOp)

writeRuleCFile
  :: FilePath
     -> Bool
     -> Bool
     -> Bool
     -> ModName
     -> Maybe (PolicyDecl QSym)
     -> ModSymbols
     -> UsedSymbols
     -> TagInfo
     -> IO ()
writeRuleCFile cFile debug profile _logging topMod policy
               modSyms usedSyms tinfo =
  writeFile cFile $ unlines $
  cHeader debug profile ++ ["\n"] ++
  [renderC $ ruleLogStructure modSyms topMod policy
          ++ policyTypeHelpers modSyms usedSyms
          ++ translateTopPolicy debug profile modSyms usedSyms
                                tinfo topMod policy]

policySuccessName, policyIFailName, policyEFailName :: String
policySuccessName = "POLICY_SUCCESS"
policyIFailName   = "POLICY_IMP_FAILURE"
policyEFailName   = "POLICY_EXP_FAILURE"

ruleLogStructure :: ModSymbols -> ModName -> Maybe (PolicyDecl QSym) -> [Definition]
ruleLogStructure _ _ Nothing = []
ruleLogStructure ms topMod (Just p) =
  [cunit|
    const int ruleLogMax = $int:(polCount);
    char* ruleLog[$int:(polCount + 1)];
    int ruleLogIdx = 0;

        void logRuleEval(const char* ruleDescription) {
          if(ruleLogIdx < ruleLogMax){
            ruleLog[ruleLogIdx] = ruleDescription;
            if(ruleLogIdx <= ruleLogMax){
              ruleLogIdx++;
            }
          }
        }
        void logRuleInit() {
          ruleLogIdx = 0;
          ruleLog[ruleLogMax] = "additional rules omitted...";
        }
        const char* nextLogRule(int* idx) {
          if(*idx < ruleLogIdx)
            return ruleLog[(*idx)++];
          return 0;
        }
  |]
    where
      -- TODO: it's a little inefficient to call this both here and later
      -- during policy translation
      polCount :: Int
      polCount = let (ds1,ds2) = topPolicyPieces ms topMod p in
                   length ds1 + length ds2

-- Most policy evaluation functions need access to the operands tag sets.  For
-- convenience, we fix one set of names used as arguments to functions.
pcArgName,ciArgName,op1ArgName,op2ArgName,op3ArgName :: String
pcArgName = opsSetsArgName ++ "pc"
ciArgName = opsSetsArgName ++ "ci"
op1ArgName = opsSetsArgName ++ "op1"
op2ArgName = opsSetsArgName ++ "op2"
op3ArgName = opsSetsArgName ++ "op3"

memArgName,opsSetsArgName, resSetsArgName, contextArgName :: String
memArgName = opsSetsArgName ++ "mem"
opsSetsArgName = operandsArgName ++ "->"
resSetsArgName = resultsArgName ++ "->"
contextArgName = "ctx"

operandsArgName, resultsArgName, resultsPC, resultsRD, resultsCSR :: String
operandsArgName = "ops"
resultsArgName = "res"
resultsPC = resSetsArgName ++ "pc"
resultsRD = resSetsArgName ++ "rd"
resultsCSR = resSetsArgName ++ "csr"

-- For convenience, we define a few commonly used types and parameter/argument
-- lists.
contextType :: Type
contextType = [cty| typename context_t |]

operandsType :: Type
operandsType = [cty| typename operands_t |]

resultsType :: Type
resultsType = [cty| typename results_t |]

policyInputParams :: [Param]
policyInputParams =
  [cparams|$ty:contextType* $id:contextArgName,
           $ty:operandsType* $id:operandsArgName,
           $ty:resultsType* $id:resultsArgName|]

policyInputArgs :: [Exp]
policyInputArgs =
  map (\x -> [cexp|$id:x|])
      [contextArgName, operandsArgName, resultsArgName]


-- Here we define some globals and helper functions that are used to manipulate
-- user-defined datatypes.
--
-- Currently the only supported type is ints, possibly with a fixed range.  We
-- define two things for each declared type: The next unused value (as a global)
-- and a function to get a new one (respecting the defined range).
policyTypeHelpers :: ModSymbols -> UsedSymbols -> [Definition]
policyTypeHelpers ms us = concatMap typeHelpers $ usedTypes ms us
  where
    typeHelpers :: (ModName, TypeDecl QSym) -> [Definition]
    typeHelpers (mn, TypeDecl _ nm (TDTInt _ mrange)) =
      [cunit|
        typename uint32_t $id:globalNm = 0;

        typename uint32_t $id:(typeGenFuncName qualifiedName)($ty:contextType* $id:contextArgName) {
          $id:contextArgName->cached = false;
          typename uint32_t newval = $id:globalNm;
          $id:globalNm = $exp:updateVal;
          return newval;
        }|]
      where
        qualifiedName = resolveQSym ms mn nm
        globalNm :: String
        globalNm = typeUsedGlobalName qualifiedName

        updateVal :: Exp
        updateVal = case mrange of
                      Nothing -> [cexp|$id:globalNm + 1|]
                      Just count -> [cexp|($id:globalNm + 1) % $exp:count|]
    typeHelpers (_, TypeDecl _ _(TDTTagSet _)) = []

typeUsedGlobalName, typeGenFuncName :: QSym -> String
typeUsedGlobalName qs = typeName qs ++ "_next_fresh"
typeGenFuncName qs = typeName qs ++ "_generator"

-- Policy rules contain clauses like:
--
--    g (foo = {X,Y}, bar = z -> baz = z)
--
-- Here, foo, bar and baz are either: "code", "env", or a name specified in the
-- opgroup declaration for g.  That opgroup declaration explains which tag set,
-- during policy evaluation, corresponds to the particular name.
--
-- We process the opgroup declarations into a convenient data structure for
-- looking up this information.  For each opgroup, we build two association
-- lists mapping QSyms (the names used in the policy) to a "TagSpec", which are
-- fixed names for the inputs of policy evaluation.  One list is for the LHS of
-- rules in this opgroup, and the other is for the RHS.
--
-- Note that "code" and "env" don't appear in these lists as qsyms - this
-- structure stores only the names that appear in opgroup declarations.
data OpGroupNames = OGNames {ognPats :: [(QSym,TagSpec)],
                             ognExps :: [(QSym,TagSpec)]}

-- This maps the name of an opgroup to its OpGroupNames structure.
type OpGroupMap = M.Map QSym OpGroupNames

buildOGMap :: ModSymbols -> UsedSymbols -> OpGroupMap
buildOGMap ms us = foldl' (flip $ uncurry M.insert)
                            M.empty (map declNames opGroupDecls)
  where
    opGroupDecls :: [(ModName, GroupDecl [ISA] QSym)]
    opGroupDecls = usedGroups ms us

    declNames :: (ModName, GroupDecl [ISA] QSym) -> (QSym, OpGroupNames)
    declNames (mn, GroupDecl _ groupNm leftParams rightParams _) =
      (qualifyQSym mn groupNm,
       OGNames {ognPats = map paramNames leftParams,
                ognExps = map paramNames rightParams})

    paramNames :: GroupParam QSym -> (QSym,TagSpec)
    paramNames (GroupParam _ ts qs) = (qs,ts)

-- patOperands and expOperands compute a map from the operand names that
-- appear in a rule to the C identifier for the relevant tag set.  For
-- patterns, this will be the name of a pointer to the tag set being examined.
-- For rules, it is the index into the array (NOTE: this is a macro, not a
-- variable name).  unknownOGMsg is a helper to avoid duplication of error
-- messages.
--
-- Args:
--  - The opGroupMap (computed by buildOGMap)
--  - The opgroup's name
unknownOGMsg :: QSym -> String
unknownOGMsg og = "Error: unknown opgroup " ++ tagString og ++ ".\n"

patOperands :: OpGroupMap -> QSym -> [(QSym, String)]
patOperands ogMap og =
  case M.lookup og ogMap of
    Nothing -> error $ unknownOGMsg og
    Just ogNames -> standardOperands
                 ++ (map (\(qs,ts) -> (qs, tagSpecPatName ts))
                       $ ognPats ogNames)
  where
    tagSpecPatName :: TagSpec -> String
    tagSpecPatName RS1 = op1ArgName
    tagSpecPatName RS2 = op2ArgName
    tagSpecPatName RS3 = op3ArgName
    tagSpecPatName Mem = memArgName
    tagSpecPatName Csr = op2ArgName
    tagSpecPatName ts =
      error $ "Error: illegal tag spec " ++ show ts
          ++ " in LHS of opgroup definition of " ++ tagString og ++ ".\n"

    standardOperands :: [(QSym, String)]
    standardOperands = [(QVar ["env"],pcArgName),
                        (QVar ["code"],ciArgName)]

expOperands :: OpGroupMap -> QSym -> [(QSym, String)]
expOperands ogMap og =
  case M.lookup og ogMap of
    Nothing -> error $ unknownOGMsg og
    Just ogNames -> standardOperands
                 ++ (map (\(qs,ts) -> (qs, tagSpecPatName ts))
                       $ ognExps ogNames)
  where
    tagSpecPatName :: TagSpec -> String
    tagSpecPatName RD = resultsRD
    tagSpecPatName Mem = resultsRD
    tagSpecPatName Csr = resultsCSR
    tagSpecPatName ts =
      error $ "Error: illegal tag spec " ++ show ts
          ++ " in RHS of opgroup definition of " ++ tagString og ++ ".\n"

    standardOperands :: [(QSym, String)]
    standardOperands = [(QVar ["env"],resultsPC)]

-- This function checks that the top-level declaration has the form
--    gp_1 & ... & gp_n & lp_1 & ... & lp_k
-- Where each gp_i is a "global" policy (like the loader policy) and each lp_i
-- is a normal policy like (like rwx or cfi).
--
-- It takes a PolicyEx and returns two lists - the global policies
-- and the local policies, in that order.
--
-- This should really return a maybe, instead of erroring
topPolicyPieces :: ModSymbols -> ModName -> PolicyDecl QSym
                -> ([(ModName, PolicyDecl QSym)],[(ModName,PolicyDecl QSym)])
topPolicyPieces ms topMod topDecl =
  case topLevelDeclsD topMod topDecl of
    Nothing -> error tppError
    Just decls -> case splitDecls [] decls of
      Nothing -> error tppError
      Just split -> split
  where
    -- Computes the names of the policies composed with &s, in order
    topLevelDeclsD :: ModName -> PolicyDecl QSym
                   -> Maybe [(ModName,PolicyDecl QSym)]
    topLevelDeclsD mn (PolicyDecl _ _ _ pe@(PECompModule _ _ _)) =
      topLevelDeclsE mn pe
    topLevelDeclsD mn (PolicyDecl _ _ _ pe@(PEVar _ _)) =
      topLevelDeclsE mn pe
    topLevelDeclsD mn p = Just [(mn,p)]

    topLevelDeclsE :: ModName -> PolicyEx QSym
                   -> Maybe [(ModName,PolicyDecl QSym)]
    topLevelDeclsE _ (PEVar _ x) =
      let (mn',p') = getPolicy ms topMod x in topLevelDeclsD mn' p'
    topLevelDeclsE mn (PECompModule _ p1 p2) = do
      ds1 <- topLevelDeclsE mn p1
      ds2 <- topLevelDeclsE mn p2
      return $ ds1 ++ ds2
    topLevelDeclsE _ _ = Nothing

    -- This confirms the list is globals at the front and locals at the back,
    -- and splits them.
    splitDecls :: [(ModName,PolicyDecl b)]
               -> [(ModName,PolicyDecl b)]
               -> Maybe ([(ModName,PolicyDecl b)],[(ModName,PolicyDecl b)])
    splitDecls _ [] = Nothing
    splitDecls gacc ((p@(_,PolicyDecl _ PLGlobal _ _)):ps) =
      splitDecls (p:gacc) ps
    splitDecls gacc ps =
      if all (\(_,PolicyDecl _ pll _ _) -> pll == PLLocal) ps then
        Just (reverse gacc,ps)
      else
        Nothing

    tppError :: String
    tppError = "Error: top-level policy must have the form:\n\n"
            ++ "   gp_1 & ... & gp_n & lp_1 & ... & lp_k\n\n"
            ++ "Where each gp_i is a \"global\" policy name (like loader) and "
            ++ "each lp_i is a \"normal\" policy name (like rwx or cfi).\n"
            ++ "There must be at least one \"normal\" policy.\n"


-- The policy mask is used to "hide" the irrelevant parts of a tag set, which
-- is sometimes useful for efficient tag set operations.
--
-- The mask has the same type as a tag set's array.  If it is bitwise "or"ed
-- with that array, only the tags declared in the relevant module remain.
-- This includes data arguments.
policyMaskName :: PolicyDecl QSym -> String
policyMaskName (PolicyDecl _ _ n _) =
  "policy_mask_" ++ (unqualSymStr n)

-- The op-group mask is used to "hide" the op group bits in a tag set, which
-- is sometimes needed when copying tags within a rule
ogMaskName :: String
ogMaskName = "og_mask"

policyMask :: ModSymbols -> UsedSymbols -> TagInfo
           -> (ModName, PolicyDecl QSym) -> Definition
policyMask _ _ (TagInfo {tiArrayLength}) (_, pd@(PolicyDecl _ PLGlobal _ _)) =
  [cedecl|const typename META_SET_TAG_TYPE $id:(policyMaskName pd)[META_SET_WORDS] =
            $init:initializer;|]
  where
    initializer :: Initializer
    initializer =
      CompoundInitializer (replicate (fromIntegral tiArrayLength) allOnes)
                          noLoc

    allOnes :: (Maybe Designation,Initializer)
    allOnes = (Nothing, ExpInitializer [cexp|-1|] noLoc)
policyMask ms us tinfo (mn, pd@(PolicyDecl _ PLLocal _ _)) =
  [cedecl|const typename META_SET_TAG_TYPE $id:(policyMaskName pd)[META_SET_WORDS] =
            $init:initializer;|]
  where
    initializer :: Initializer
    initializer = CompoundInitializer (map bi fieldMasks) noLoc
      where
        bi :: Exp -> (Maybe Designation,Initializer)
        bi e = (Nothing,ExpInitializer e noLoc)

    -- We construct fieldMasks from the actual tags
    -- declared in this module (declaredTags)
    fieldMasks :: [Exp]
    fieldMasks = fixedTagSetFields tinfo $
         (map (\(TagDecl _ nm args) ->
                     (nm, replicate (length args) [cexp|-1|]))
              qualifiedTags)

    qualifiedTags :: [TagDecl QSym]
    qualifiedTags = map (fmap (resolveQSym ms mn)) declaredTags

    declaredTags :: [TagDecl QSym]
    declaredTags = moduleTags ms us mn

ogMasks :: TagInfo -> [Definition]
ogMasks tinfo =
  [cedecl|const typename uint32_t $id:(ogMaskName)[META_SET_WORDS] =
            $init:initializer;|]:[]
  where
    initializer :: Initializer
    initializer = CompoundInitializer (map bi ogMask) noLoc
      where
        bi :: Exp -> (Maybe Designation,Initializer)
        bi e = (Nothing,ExpInitializer e noLoc)
        ogMask :: [Exp]
        ogMask = fixedTagSetFields tinfo (map (,[]) $ tiGroupNames tinfo)

-- Given a collection of tags, this computes the corresponding tag set array,
-- as a lit of C expressions.  Tags are provided as a pair (QSym,[Exp]), with
-- the QSym identifying the tag and the [Exp] carrying the arguments, if any.
-- The arguments might be fixed values or might be variables that are in-scope
-- in the context where this is called (which is why we don't just use Word32
-- here).
fixedTagSetFields :: TagInfo -> [(QSym,[Exp])] -> [Exp]
fixedTagSetFields ti@(TagInfo {tiTagBitPositions,tiTagArgInfo,tiArrayLength}) tags =
  map eToExp $ elems $ A.runSTArray $ do
    array <- A.newArray (0,tiArrayLength-1) (Left 0)
    mapM_ (addTag array) tags
    return array
  where
    eToExp :: Either Word32 Exp -> Exp
    eToExp e = case e of
                 Left w -> [cexp|$int:w|]
                 Right c -> c

    addTag :: A.STArray s Word32 (Either Word32 Exp) -> (QSym,[Exp]) -> ST s ()
    addTag array (tName,tArgs) = do
      ew <- A.readArray array bitWordIndex
      case ew of
        Left w -> A.writeArray array bitWordIndex (Left $ w .|. (2 ^ bitWordBit))
        Right _ -> error $ "Internal error: conflict between bit tag and "
                        ++ "tag arg in fixedTagSetFields."
      mapM_ (\(p,val) -> A.writeArray array p (Right val)) argPairs
      where
        overallBitPosition :: Word32
        overallBitPosition =
          case M.lookup tName tiTagBitPositions of
            Nothing -> error $ "Unknown tag " ++ tagString tName
                            ++ " in fixed tag set bit computation."
            Just i -> i

        tagArgPositions :: [Word32]
        tagArgPositions =
          case M.lookup tName tiTagArgInfo of
            Nothing -> error $ "Unknown tag " ++ tagString tName
                          ++ " in fixed tag set arg computation."
            Just ws -> map fst ws

        bitWordIndex, bitWordBit :: Word32
        bitWordIndex = div overallBitPosition 32
        bitWordBit = mod overallBitPosition 32

        argPairs :: [(Word32,Exp)]
        argPairs =
          if (length tArgs) /= (length tagArgPositions) then
            error $ "Invalid number of arguments to " ++ tagString tName
          else
            zip tagArgPositions tArgs

-- Translates the "main" policy.
--
-- It returns several definitions, which must be included in the C file in the
-- order they are returned.  There will be one top-level "eval_policy"
-- function, which calls a bunch of helper functions.  There will one helper
-- function per named policy in the top-level composition.
--
-- Each generated function takes the arguments defined in "policyInputParams".
-- The first 6 of these are pointers to tag sets that describe the current
-- state of the system.
--
-- The last two inputs are output arguments: one is a tag set array, where
-- result tag sets are stored.  The other is a bool array, where we track
-- whether the rule chosen provided an updated tag set for each output
-- position (i.e., whether this function has modified each tag set in the
-- previous array).  eval_policy assumes that the provided meta_set array
-- begins with empty tag sets, and the individual policy evaluation functions
-- assume that these sets contain no tags from the policy in question.
--
-- The eval_policy functions do not check if the computed tag sets already
-- exist or do any canonization - that is the responsibility of the caller.
translateTopPolicy :: Bool -> Bool -> ModSymbols -> UsedSymbols -> TagInfo
                   -> ModName -> Maybe (PolicyDecl QSym) -> [Definition]
translateTopPolicy _debug _profile _ms _us _ _ Nothing =
   [ [cedecl|
        int eval_policy ($params:policyInputParams) {
          return $id:policySuccessName;
        }|] ]
translateTopPolicy debug profile ms us tinfo topMod (Just pd) =
  ogMasks tinfo ++ policyMasks ++ evalHelpers ++
    [ [cedecl|
        int eval_policy ($params:policyInputParams) {
          int $id:resultVar = $id:policyIFailName;

          $items:topDebugStms

          $stms:globalChecks
          $stms:localChecks

          // any policy failure will result in an early return.
          return $id:policySuccessName;
        }|] ]
  where
    globalPolicies, localPolicies :: [(ModName, PolicyDecl QSym)]
    (globalPolicies,localPolicies) = topPolicyPieces ms topMod pd

    policyMasks :: [Definition]
    policyMasks = map (policyMask ms us tinfo) (globalPolicies ++ localPolicies)

    resultVar :: String
    resultVar = "evalResult"

    debugBufVar :: String
    debugBufVar = "debugMsg"

    ogMap :: OpGroupMap
    ogMap = buildOGMap ms us

    evalHelpers :: [Definition]
    evalHelpers = map (policyEval debug profile ms ogMap tinfo)
                      (globalPolicies ++ localPolicies)

    -- The results from global and local policy evaluation are handled
    -- differently, implementing the different semantics of ^ and &.
    --
    -- Explicit failure: In both cases, an explicit failure is counted as an
    -- explicit failure of the whole policy.
    --
    -- Success: For a global policy, success ends policy evaluation successfully
    -- (e.g., we do not run the normal policies on the special bits of the
    -- loader).  For a local policy, success adds to the computed result tag
    -- sets, but execution continues with the next composed local policy.
    --
    -- Implicit failure: For a global policy, implicit failure is the usual case
    -- and policy execution continues.  This occurs whenever we aren't in
    -- "special" code like the loader.  For a local policy, implicit failure
    -- causes failure of the top-level policy: each policy composed with & must
    -- have a rule for every instruction.
    globalChecks :: [Stm]
    globalChecks = concatMap globalCheck globalPolicies
      where
        globalCheck :: (ModName, PolicyDecl QSym) -> [Stm]
        globalCheck (_, pol) = [cstms|
          $stms:(policyDebugStmsPre pol);
          $id:resultVar = $id:(singlePolicyEvalName pol)($args:policyInputArgs);
          $stms:(policyDebugStmsPost);
          if($id:resultVar == $id:policySuccessName) {
            return $id:policySuccessName;
          } else if($id:resultVar == $id:policyEFailName) {
            return $id:policyEFailName;
          }
        |]


    localChecks :: [Stm]
    localChecks = concatMap localCheck localPolicies
      where
        localCheck :: (ModName, PolicyDecl QSym) -> [Stm]
        localCheck (_, pol) = [cstms|
          $stms:(policyDebugStmsPre pol);
          $id:resultVar = $id:(singlePolicyEvalName pol)($args:policyInputArgs);
          $stms:(policyDebugStmsPost);
          if($id:resultVar != $id:policySuccessName) {
            return $id:resultVar;
          }
        |]

    topDebugStms :: [BlockItem]
    topDebugStms =
       if debug then
         [citems|
           char $id:debugBufVar[80];
           snprintf($id:debugBufVar, 80,
                    "\nNew Instruction. PC: 0x%lx\n", $id:contextArgName->epc);
           debug_msg($id:contextArgName, $id:debugBufVar);
           debug_msg($id:contextArgName, "  Policy input:\n");
           debug_operands($id:contextArgName, $id:operandsArgName);
         |]
       else []

    policyDebugStmsPre :: PolicyDecl QSym -> [Stm]
    policyDebugStmsPre pol =
      if debug then
        [cstms|debug_msg($id:contextArgName, $string:("  Evaluating policy: " ++ (policyDotName pol) ++ "\n"));|]
      else []

    policyDebugStmsPost :: [Stm]
    policyDebugStmsPost =
      if debug then
        [cstms|debug_msg($id:contextArgName, "    Result: ");
               debug_status($id:contextArgName, $id:resultVar);
               debug_msg($id:contextArgName, "    Metadata Updates:\n");
               debug_results($id:contextArgName, $id:resultsArgName);|]
      else []

singlePolicyEvalName :: PolicyDecl QSym -> String
singlePolicyEvalName (PolicyDecl _ _ n _) =
  "policy_eval_" ++ (unqualSymStr n)

-- Builds a function that evaluates a specific policy.  Intended to be called
-- individually on the named, composed components of the top-level policy.
--
-- The final two parameter to the generated C function are "output" arguments.
--
-- The first is an array of tag sets, where the results of policy evaluation
-- may be stored.  The generated function assumes these sets do not yet
-- contain any of this policy's tags.  If policy evaluation is successful, the
-- sets will be modified.
--
-- The second is an array of bools, of the same length as the previous array.
-- Each bool records whether this policy provided an updated version of the
-- corresponding tag set.
--
-- If this is a normal policy (like RWX) this function will add only tags from
-- the RWX module to the output sets.  Policies are evaluated sequentially, so
-- there may already be tags from other policies on the lists, but they don't
-- affect this policy and won't be modified.  If it's a global policy, the
-- sets might be completely reworked.
policyEval :: Bool -> Bool -> ModSymbols -> OpGroupMap
           -> TagInfo -> (ModName, PolicyDecl QSym)
           -> Definition
policyEval debug _profile ms ogMap tagInfo (modN, pd@(PolicyDecl _ _ _ pEx)) =
  [cedecl|
       int $id:(singlePolicyEvalName pd) ($params:policyInputParams) {

         $stm:body

         // Each result clause returns, so if we reach here it is an implicit failure.
         return $id:policyIFailName;
       } |]
  where
   body :: Stm
   body = Block p' noLoc
     where
       p' = translatePolicy debug ms ogMap pd tagInfo modN pEx

-- Takes as arguments:
--  - whether to print debug info
--  - The global symbol table
--  - Info about opgroups
--  - the policy declaration (used for policy name)
--  - the tag encoding list
--  - The enclosing module name
--  - the policy itself.
--
-- Results: A [BlockItem].  This is a list of statements that implements the
-- policy and is intended to be part of the eval_policy function.  These
-- statements will return one of policySuccessName, policyIFailName, or
-- policyEFailName.  In the first case, the function will add the appropriate
-- tags from this policy to the array of result tag lists.
translatePolicy :: Bool -> ModSymbols -> OpGroupMap ->  PolicyDecl QSym
                -> TagInfo -> ModName
                -> PolicyEx QSym -> [BlockItem]
translatePolicy dbg ms ogMap pd tagInfo modN (PEVar _ x) =
  let (modN', (PolicyDecl _ _ _ p)) = getPolicy ms modN x in
    translatePolicy dbg ms ogMap pd tagInfo modN' p
translatePolicy dbg ms ogMap pd tagInfo modN (PECompExclusive _ p1 p2) =
  [citems|$items:p1';
          $items:p2'
          |]
  where
     p1' = translatePolicy dbg ms ogMap pd tagInfo modN p1
     p2' = translatePolicy dbg ms ogMap pd tagInfo modN p2
translatePolicy dbg ms ogMap pd tagInfo modN (PECompPriority l p1 p2) =
  translatePolicy dbg ms ogMap pd tagInfo modN (PECompExclusive l p1 p2)
translatePolicy _ _ _ _ _ _ (PENoChecks _) =
  [citems| return $id:policySuccessName;|]
translatePolicy _ _ _ _ _ _ (PECompModule loc _ _) =
  error $ "Unsupported: PECompModule in translatePolicy at " ++ ppSrcPos loc
translatePolicy _ _ _ _ _ _
                (PERule _ (RuleClause loc _ _ (Just _) _)) =
  error $ "Unsupported: rule guard at " ++  ppSrcPos loc
translatePolicy dbg ms ogMap pd tagInfo modN
                (PERule _ rc@(RuleClause _ ogrp rpat Nothing rres)) =
  [citems|
       if(ms_contains($id:ciArgName,$id:(tagName (qualifiedOpGrpMacro)))) {
         int $id:matchVar = $exp:patExp;
         if ($id:matchVar) {
           $stms:debugPrints
           $stms:ruleEvalLog
           $items:ruleResult
         }
       }
   |]
  where
    qualifiedOpGrp :: QSym
    qualifiedOpGrp = resolveQSym ms modN ogrp

    matchVar :: String
    matchVar = "isRuleMatch"

    qualifiedOpGrpMacro :: QSym
    qualifiedOpGrpMacro = qualifyQSym (moduleForQSym ms modN ogrp) $ groupPrefix ogrp
    mask = policyMaskName pd

    patExp :: Exp
    boundNames :: [(QSym,Exp)]
    (patExp,boundNames) =
      translatePatterns ms modN mask tagInfo operandIDs rpat
      where
        operandIDs :: [(QSym, String)]
        operandIDs = patOperands ogMap qualifiedOpGrp

    ruleResult :: [BlockItem]
    ruleResult = translateRuleResult ms modN mask oprLookup boundNames tagInfo rres
      where
        oprLookup :: [(QSym,String)]
        oprLookup = expOperands ogMap qualifiedOpGrp

    debugPrints :: [Stm]
    debugPrints =
      if dbg then
        [cstms|
          debug_msg($id:contextArgName,
                    $string:("    Rule Matched: " ++ (printRuleClause rc)
                                                  ++ "\n"));
        |]
      else []

    ruleEvalLog :: [Stm]
    ruleEvalLog =
        [cstms|
          logRuleEval($string:(qualifiedShowRule pd));
        |]

    qualifiedShowRule :: PolicyDecl QSym -> String
    qualifiedShowRule p = policyDotName p ++ ":" ++ printRuleClause rc

-- Args:
--   - The symbol map
--   - The module name
--   - The policy mask
--   - The tag encoding list
--   - An association list mapping operand names to C identifiers
--   - patterns
-- Results:
--   - A C expression that evaluates to "1" if the pattern
--     matches and "0" otherwise
--   - A map from policy variable names to the corresponding C expression.
--
-- XXX This function has become a bit crufty as features have been added, and
-- could do with a re-write.
translatePatterns :: ModSymbols
                  -> ModName
                  -> String
                  -> TagInfo
                  -> [(QSym,String)]
                  -> [BoundGroupPat QSym]
                  -> (Exp,[(QSym,Exp)])
translatePatterns ms mn mask tagInfo ogmap pats =
  foldl' patternAcc ([cexp|1|],defaultEnv) pats
  where
    -- default binding for the env var, syntax sugar to allow it to be used in result
    -- without having been defined
    defaultEnv :: [(QSym,Exp)]
    defaultEnv = [(QVar ["env"],[cexp|$id:pcArgName|])]
    patternAcc :: (Exp,[(QSym,Exp)]) -> BoundGroupPat QSym
               -> (Exp,[(QSym,Exp)])
    patternAcc (e,ids) pat =
      foldl' addBindings ([cexp|$exp:e' && $exp:e|],ids) ids'
      where
        (e',ids') = translateBGPat pat

    -- This adds a pattern bindings to an existing set.  We allow non-linear
    -- bindings for tag arguments, so we check names as they are added to see if
    -- a binding already exists, and compute an expresion that accumulates all
    -- the implied equality constraints.
    addBindings :: (Exp,[(QSym,Exp)]) -> (QSym,Exp) -> (Exp,[(QSym,Exp)])
    addBindings (es,bnds) (qs,e) =
      case lookup qs bnds of
        Nothing -> (es,(qs,e):bnds)
        Just e' -> ([cexp|($exp:e == $exp:e') && $exp:es|],bnds)

    -- Give this a BoundGroupPat, and it generates (a) an expression that is
    -- true iff the pattern matches*, and (b) a list associating the names bound
    -- in this pattern with the C name for the relevant tag set.
    --
    --  *This does NOT account for non-linear pattern matching constraints in
    -- tag arguments, which are handled by the caller.
    translateBGPat :: BoundGroupPat QSym -> (Exp,[(QSym,Exp)])
    translateBGPat (BoundGroupPat loc tsID pat) =
      case lookup tsID ogmap of
        Nothing -> error $ "No opgroup binding for operand \"" ++ show tsID
                        ++ "\" at " ++ ppSrcPos loc
        Just tsName -> translateTSPat tsID tsName pat

    qualifyTag :: Tag QSym -> Tag QSym
    qualifyTag (Tag sp nm args) = Tag sp (resolveQSym ms mn nm) args

    -- Give this the name of a pointer to a meta_set_t, and a TagSetPattern, and
    -- it will return (a) an expression that is true iff the pattern matches,
    -- and (b) a list of names that the pattern binds to the input tag set.
    translateTSPat :: QSym -> String -> TagSetPat QSym -> (Exp,[(QSym,Exp)])
    translateTSPat tsID ts  (TSPAny _) = ([cexp|1|],[(tsID,[cexp|$id:ts|])])
    translateTSPat tsID ts (TSPAtLeast _ tes) =
      foldl' (\(e1,bnds1) (e2,bnds2) -> (BinOp Land e1 e2 noLoc,bnds1++bnds2))
             ([cexp|1|],[(tsID,[cexp|$id:ts|])])
             (map checkAtLeast tes)
      where
        checkAtLeast :: TagEx QSym -> (Exp,[(QSym,Exp)])
        checkAtLeast (TagEx _ t) = checkContains ts $ qualifyTag t
        checkAtLeast (TagPlusEx _ t) = checkContains ts $ qualifyTag t
        checkAtLeast (TagMinusEx _ t) = checkAbsent ts $ qualifyTag t
    translateTSPat tsID ts (TSPExact _ tags) =
      (foldl' (\e1 e2 -> [cexp|$exp:e1 && $exp:e2|])
              [cexp|1|]
              (map checkField exactFields),
              [(tsID,[cexp|$id:ts|])] ++ argBindings)
      where
        -- Here we cheat a bit!  We call "fixedTagSetFields", but we only care
        -- about the bitfield parts of its output, not the tag arguments.  We
        -- pass in 0 for the arguments, just to satisfy the preconditions of
        -- that function.
        --
        -- Separately, we use the "argBinding" function (which is also used in
        -- the at least case) to capture any argument bindings and any equality
        -- contraints created by non-linear pattern matching.
        tagQSyms :: [(QSym,[Exp])]
        tagQSyms = map (\(Tag _ qs args) -> (resolveQSym ms mn qs,map (\_ -> [cexp|0|]) args)) tags

        argBindings :: [(QSym,Exp)]
        argBindings = concatMap tagBindings tags
          where
            tagBindings :: Tag QSym -> [(QSym,Exp)]
            tagBindings (Tag _ qs args) =
              case M.lookup (resolveQSym ms mn qs) (tiTagArgInfo tagInfo) of
                Nothing -> error $ "Internal error: unknown tag " ++ tagString qs
                                ++ " in translateTSPat's arg lookup."
                Just argInfo ->
                  mapMaybe (argBinding ts) $
                    zipWith (\f (w,_) -> (w,f)) args argInfo

        exactFields :: [(Word32,Exp)]
        exactFields = zip [0..(tiNumBitFields tagInfo - 1)]
                          (fixedTagSetFields tagInfo tagQSyms)

        checkField :: (Word32,Exp) -> Exp
        checkField (idx,val) =
          [cexp|((($id:ts->tags)[$exp:idx]) & $id:mask[$idx]) == $exp:val|]

    -- These build a C boolean expression that checks whether a tag set (first
    -- argument) contains or does not contain a particular tag (second
    -- argument).  They also record any tag argument bindings.  Tag argument in
    -- patterns must be either "_" or a variable name.
    checkContains, checkAbsent :: String -> Tag QSym -> (Exp,[(QSym,Exp)])
    checkContains ts (Tag _ qn args) =
      case M.lookup qn (tiTagArgInfo tagInfo) of
        Nothing -> error $ "Internal error: tag " ++ tagString qn
                        ++ " missing from tagArgInfo map in checkContains."
        Just argInfo ->
           ([cexp|ms_contains($id:ts,$id:(tagName qn))|],
            mapMaybe (argBinding ts) $
              zipWith (\(idx,_) bnd -> (idx,bnd)) argInfo args)
    checkAbsent ts (Tag _ qn _) =
      ([cexp|(!(ms_contains($id:ts,$id:(tagName qn))))|],[])

    argBinding :: String -> (Word32,TagField QSym) -> Maybe (QSym,Exp)
    argBinding _ (_,TFNew p) =
      error $ "Illegal: Attempt to create \"new\" tag data in pattern "
           ++ "at " ++ ppSrcPos p
    argBinding ts (idx,TFVar _ v) = Just (v,[cexp|($id:ts -> tags)[$int:idx]|])
    argBinding _ (_,TFAny _) = Nothing
    argBinding _ (_,TFInt p _) =
      error $ "Unsupported: Specific integer in tag field pattern at "
           ++ ppSrcPos p
    argBinding _ (_,TFBinOp p b _ _) =
      error $ "Illegal: Attempt to create use binary operator \""
           ++ printTagFieldBinOp b ++ "\" in pattern "
           ++ "at " ++ ppSrcPos p

-- Arguments:
--   - The module symbols
--   - The module name
--   - The name of the policy mask
--   - An association list mapping operands to C macros based on the opgroup.
--   - A mapping from policy variables to C expressions.
--   - The result to be translated.
-- Results:
--   - A series of statements.  These will have the result of returning
--     policyEFail from the current function if the rule result is failure.  If
--     the rule result is to generate new tags, they'll assign new tags into the
--     result array and return policySuccess from the current function.
translateRuleResult :: ModSymbols -> ModName -> String -> [(QSym,String)]
                    -> [(QSym,Exp)] -> TagInfo -> RuleResult QSym
                    -> [BlockItem]
-- handle the explicit failure case by printing a message and return failure
translateRuleResult _ _ _ _ _ _ (RRFail _ msg) =
  [citems| $id:contextArgName->fail_msg = $string:msg;
           return $id:policyEFailName;|]
translateRuleResult ms topMod mask ogMap varMap tagInfo (RRUpdate sp updates) =
  case missingOperands of
    Left errMsg -> error errMsg
    Right defaultBlocks ->
         defaultBlocks
      ++ (concatMap (translateBoundGroupEx ms topMod mask ogMap varMap tagInfo)
                    updates)
      ++ [ [citem|return $id:policySuccessName;|] ]
  where
    -- This implements a check that the rule provides updated metadata for any
    -- memory/register updated by the instruction, according to the opgroup.
    -- The user is allowed to leave off the result PC metadata, in which case
    -- we assume it does not change.  We compute either an error message or
    -- some BlockItems (which implement the default case for env if it is
    -- necessary).
    missingOperands :: Either String [BlockItem]
    missingOperands = case (otherMissing,envMissing) of
      -- Missing operand other than env.
      (Just (qs,_),_) -> Left $
           "Rule is missing updated metadata for operand \"" ++ tagString qs
        ++ "\", which is requird by its opgroup (" ++ ppSrcPos sp ++ ").\n"
      -- Missing no operands.
      (Nothing,False) -> Right []
      -- Missing only env.
      (Nothing,True)  -> Right $
        translateBoundGroupEx ms topMod mask ogMap varMap tagInfo $
            BoundGroupEx sp (QVar ["env"]) (TSEVar sp (QVar ["env"]))
        -- CJC: This feels a little hacky because it depends on (QVar ["env"])
        -- to mean the right thing.  But I definitely don't want to duplicate
        -- the functionality of translateBoundGroupEx.  Hmm.

    updatedOperands :: [QSym]
    updatedOperands = map (\(BoundGroupEx _ qs _) -> qs) updates

    envMissing :: Bool
    envMissing = not $ (QVar ["env"]) `elem` updatedOperands

    otherMissing :: Maybe (QSym,String)
    otherMissing = find (\(qs,_) -> not $ qs == (QVar ["env"])
                                       || qs `elem` updatedOperands)
                        ogMap

-- Arguments:
--   - The module symbols
--   - The module name
--   - The name of the policy mask
--   - An association list mapping operands to C macros based on the opgroup.
--   - A mapping from policy tag set variables to C tag set variables.
--   - The BoundGroupEx to be translated.
-- Results:
--  - A series of statements that compute a revised tag set and store it into
--    the place in the results array indicated by the LHS of the BoundGroupEx
--
-- This relies on a recursive helper function that descends through the tag set
-- expression and roughly implements the judgment from the pdf.
translateBoundGroupEx :: ModSymbols -> ModName -> String -> [(QSym,String)]
                      -> [(QSym,Exp)] -> TagInfo -> BoundGroupEx QSym
                      -> [BlockItem]
translateBoundGroupEx ms mn mask ogMap varMap tagInfo (BoundGroupEx loc opr tse) =
  case lookup opr ogMap  of
    Nothing -> error $ "Rule result uses invalid operand " ++ show opr
                        ++ "(" ++ ppSrcPos loc ++ ")"
    Just resPositionName ->
      -- Note that here we remove any opgroup tags from the computed tag sets.
      -- This kind of makes sense - if you write to code memory, you want to
      -- wipe the opgroups because the new value may not be the same kind of
      -- instruction, or any instruction at all.  And in general users don't
      -- know that opgroups are in tag sets, so they shouldn't expect them to be
      -- preserved.  This may be wrong, though, for "global" policies like the
      -- loader.
      [citems|
        { typename meta_set_t $id:topVar;
          $items:evalItems;
          for(int i = 0; i < META_SET_BITFIELDS; i++) {
              ($id:resPositionName)->tags[i] |= ($id:topVar.tags[i] & $id:mask[i]);
          }
          for(int i = META_SET_BITFIELDS; i < META_SET_WORDS; i++) {
            if($id:mask[i]) {
              $id:resPositionName->tags[i] =
                $id:topVar.tags[i];
            }
          }
          $id:resHasResult = true;
        }
      |]
      where
        evalItems :: [BlockItem]
        (evalItems,_) = translateTagSetEx ms mn vars topVar varMap tagInfo tse

        resHasResult :: String
        resHasResult = resPositionName ++ "Result"

        topVar :: String
        topVar = "tseEvalVar0"

        vars :: [String]
        vars = zipWith (++) (repeat "tseEvalVar") (map show ([1..] :: [Int]))


-- translateTagSetEx does the work of actually evaluating a TagSetEx.  It
-- recursively descends down the structure of a TagSetEx, accumulating the
-- result into a stack-allocated tag set.
--
-- Arguments:
--
--   - a supply of fresh variables.
--   - a variable name x, of type meta_set_t.  This is the stack allocated
--     meta_set into which we will accumulate the result.  The contents of x in
--     positions not relevant to this policy may be garbage, and can not be
--     relied on.
--   - A mapping from policy tag set variables to C tag set variables.
--   - The TagSetEx to evaluate
--
-- Results:
--   - A [BlockItem].  These statements compute the result of the input
--     TagSetEx, and store it in x.  Only the tags that are relevant to this
--     policy, according to the policy mask, should be used from x.
--   - The remaining variables from the fresh variable supply.
--
translateTagSetEx :: ModSymbols -> ModName -> [String] -> String -> [(QSym,Exp)] -> TagInfo
                  -> TagSetEx QSym -> ([BlockItem],[String])
translateTagSetEx _ _ [] _ _ _ _ =
  error "Internal error: translateTagSetEx exhausted its fresh name supply."
translateTagSetEx _ _ (_:[]) _ _ _ _ =
  error "Internal error: translateTagSetEx exhausted its fresh name supply."
translateTagSetEx _ _ vars resVar varMap _ (TSEVar loc y) =
  case lookup y varMap of
    Nothing -> error $ "Rule result uses unbound variable " ++ show y
                    ++ "(" ++ ppSrcPos loc ++ ")"
    Just ts -> ([citems|memcpy(&$id:resVar,$exp:ts,sizeof(typename meta_set_t));|],
                vars)
translateTagSetEx ms mn vars resVar varMap tagInfo (TSEExact _ tags) =
  (map (\(idx,val) -> [citem|$id:resVar.tags[$exp:idx] = $exp:val;|]) exactFields,
   vars)
  where
    exactFields :: [(Word32,Exp)]
    exactFields = zip [0..] (fixedTagSetFields tagInfo tagQSyms)

    tagQSyms :: [(QSym,[Exp])]
    tagQSyms = map (\(Tag _ qs tfs) -> (qs,map (buildArgField ms mn varMap)
                                             $ zip tfs (argInfo qs)))
                   qualifiedTags
      where
        argInfo :: QSym -> [(Word32,TypeDecl QSym)]
        argInfo qs =
          case M.lookup qs (tiTagArgInfo tagInfo) of
            Nothing -> error $ "Internal error: unknown tag " ++ tagString qs
                            ++ " in translateTagSetEx's arg lookup."
            Just ai -> ai
    qualifiedTags :: [Tag QSym]
    qualifiedTags = map (fmap (resolveQSym ms mn)) tags

translateTagSetEx ms mn vars resVar varMap tagInfo (TSEModify _ tse mods) =
  ([citems|
     $items:tseStmts;
     $items:modStmts;
   |],
   vars')
  where
    tseStmts :: [BlockItem]
    vars' :: [String]
    (tseStmts,vars') = translateTagSetEx ms mn vars resVar varMap tagInfo tse

    qualifiedMods :: [TagEx QSym]
    qualifiedMods = map (fmap (resolveQSym ms mn)) mods

    modStmts :: [BlockItem]
    modStmts = concatMap modStmt qualifiedMods

    modStmt :: TagEx QSym -> [BlockItem]
    modStmt (TagEx _ t) = tsAdd t
    modStmt (TagPlusEx _ t) = tsAdd t
    modStmt (TagMinusEx _ t) = tsRemove t

    tsAdd :: Tag QSym -> [BlockItem]
    tsAdd (Tag _ qn args) =
      case M.lookup qn (tiTagArgInfo tagInfo) of
        Nothing -> error $ "Internal error: unknown tag " ++ tagString qn
                ++ " in translateTagSetEx's arg lookup."
        Just ainfo ->
            [citem|ms_bit_add(&$id:resVar,$id:(tagName qn));|]
          : map (\(tf,(loc,typ)) ->
                   [citem|$id:resVar.tags[$exp:loc] =
                      $exp:(buildArgField ms mn varMap (tf,(loc,typ)));|])
                (zip args ainfo)

    tsRemove :: Tag QSym -> [BlockItem]
    tsRemove (Tag _ qn _) =
      case M.lookup qn (tiTagArgInfo tagInfo) of
        Nothing -> error $ "Internal error: unknown tag " ++ tagString qn
                ++ " in translateTagSetEx's arg lookup."
        Just ainfo ->
            [citem|ms_bit_remove(&$id:resVar,$id:(tagName qn));|]
          : map (\(loc,_) -> [citem|$id:resVar.tags[$exp:loc] = 0;|])
                ainfo
translateTagSetEx ms mn (v1:v2:vars) resVar varMap tagInfo (TSEUnion _ tse1 tse2) =
  ([citems|
     $items:tseStmts1;
     typename meta_set_t $id:v1;
     $items:tseStmts2;
     int $id:v2 = ms_union(&$id:resVar, &$id:v1);
     if($id:v2) {handle_panic("Invalid union in translateTagSetEx!\n");}
    |],
   vars'')
  where
    tseStmts1, tseStmts2 :: [BlockItem]
    vars', vars'' :: [String]
    (tseStmts1,vars') = translateTagSetEx ms mn vars resVar varMap tagInfo tse1
    (tseStmts2,vars'') = translateTagSetEx ms mn vars' v1 varMap tagInfo tse2
translateTagSetEx ms mn (v1:vars) resVar varMap tagInfo (TSEIntersect _ tse1 tse2) =
  ([citems|
     $items:tseStmts1;
     typename meta_set_t $id:v1;
     $items:tseStmts2;
     ms_intersection(&$id:resVar, &$id:v1);
    |],
   vars'')
  where
    tseStmts1, tseStmts2 :: [BlockItem]
    vars', vars'' :: [String]
    (tseStmts1,vars') = translateTagSetEx ms mn vars resVar varMap tagInfo tse1
    (tseStmts2,vars'') = translateTagSetEx ms mn vars' v1 varMap tagInfo tse2

--This builds a C expression corresponding to a tag argument field
buildArgField :: ModSymbols -> ModName -> [(QSym,Exp)]
              -> (TagField QSym,(Word32,TypeDecl QSym)) -> Exp
buildArgField _ _ varMap (TFVar sp v,_) =
  case lookup (unqualQSym v) varMap of
    Nothing ->
      error $ show varMap ++ "\n" ++ "Undefined variable "
           ++ tagString v ++ " at " ++ ppSrcPos sp
    Just e -> e
buildArgField ms mn _ (TFNew _,(_,typ)) =
  [cexp|$id:(typeGenFuncName qualifiedType)(ctx)|]
    where
      qualifiedType = resolveQSym ms mn $ qsym typ
buildArgField _ _ _ (TFAny sp,_) = error $
  "Illegal: wildcard in tag argument definition at " ++ ppSrcPos sp
buildArgField _ _ _ (TFInt sp _,_) = error $
     "Unimplemented: Specific integer provided as tag field argument at "
  ++ ppSrcPos sp
buildArgField _ _ _ (TFBinOp sp _ _ _,_) = error $
     "Unimplemented: Binary operation used in tag field argument at "
  ++ ppSrcPos sp

-- top of policy_rule.c
cHeader :: Bool -> Bool -> [String]
cHeader _debug _profile = [ "#include \"policy_meta.h\""
                         , "#include \"policy_rule.h\""
                         , "#include \"policy_meta_set.h\""
                         , "#include <stdbool.h>"
                         , "#include <stdint.h>"
                         , "#include <stdio.h>"
                         , "#include <inttypes.h>"
                         , "#include <limits.h>"
                         , "#include <string.h>"
                         , ""
                         ]
