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
module Generator where

import System.FilePath  ((</>),addTrailingPathSeparator)
import System.IO        (hPutStrLn,stderr)
import System.Directory (createDirectoryIfMissing)

import Data.List (intercalate)

import AST
import GenUtils    (fmt)
import CommonFn    (dotName,unqualSymStr,qualSymStr,dash)
import CommonTypes (Options(..))
import Symbols     (ModSymbols,SymbolTable(..),UsedSymbols)
import Tags        (TagInfo(..),buildTagInfo)
import Validate    (nubSymbols)

-- C code Templates for the generator:
import GenRuleC    (writeRuleCFile)
import GenRuleH    (writeRuleHFile)
import GenUtilsC   (writeUtilsCFile)
import GenUtilsH   (writeUtilsHFile)
import GenMetaH    (writeMetaHFile)
import GenMetaSetC (writeMetaSetCFile)
import GenMetaSetH (writeMetaSetHFile)

-- Runtime encoding information
import GenMetaY   (writeMetaYFile)
import GenModuleY (writeModuleYFile)
import GenInitY   (writeInitYFile)
import GenGroupY  (writeGroupYFile)
import GenEntityY (writeEntityYFile)

genSymbolsFile :: ModSymbols -> IO ()
genSymbolsFile modules =
  let file = "symbols.txt" in do
    hPutStrLn stderr $ "Debug: Symbols from all modules can be found in: " ++ file
    writeFile file $ unlines $ syms
  where
    syms = concatMap printModuleSymbols modules

    printModuleSymbols :: (ModName, SymbolTable QSym) -> [String]
    printModuleSymbols (qpn, st) = ["", dotName qpn] ++
      printTable "Metadata" tagSyms ++
      printTable "Policies" policySyms ++
      printTable "Groups" groupSyms
      where
        printTable tNm tFn =  header tNm $ map (unqualSymStr . fst) $ tFn st

    header :: String -> [String] -> [String]
    header _ [] = []
    header nm strs =
      map (fmt 1) $ [dash ++ " " ++ nm ++ " " ++ dash] ++ strs

genASTFile :: ModSymbols -> IO ()
genASTFile ms =
  let file = "ast.txt" in do
    hPutStrLn stderr $ "Debug: AST for parsed policies can be found in: "
                    ++ file
    writeFile file $ intercalate "\n\n" $ map dumpMod ms
    where
      dumpMod :: (ModName,SymbolTable QSym) -> String
      dumpMod (mn,st) = (replicate 78 '=')
                     ++ "\nMODULE: " ++ dotName mn ++ "\n\n"
                     ++ (intercalate "\n" $ map dumpPD $ policySyms st)
      
      dumpPD :: (QSym, PolicyDecl QSym) -> String
      dumpPD (qs,pd) =
        qualSymStr qs ++ ":\n" ++ show pd

genFiles :: Options
         -> ModSymbols
         -> UsedSymbols
         -> [(ModName, QSym)]
         -> ModName
         -> Maybe (PolicyDecl QSym)
         -> IO ()
genFiles opts allModSymTables polSyms requireSyms topMod policy = let
    allUsedSyms = nubSymbols (polSyms ++ requireSyms)

    tagSetHFile = path </> "include" </> (optFileName opts) ++ "_meta_set.h"
    tagSetCFile = path </> "src" </> (optFileName opts) ++ "_meta_set.c"

    ruleCFile = path </> "src" </> (optFileName opts) ++ "_rule.c"
    ruleHFile = path </> "include" </> (optFileName opts) ++ "_rule.h"
    utilsCFile = path </> "src" </> (optFileName opts) ++ "_utils.c"
    utilsHFile = path </> "include" </> (optFileName opts) ++ "_utils.h"

    metaHFile = path </> "include" </> (optFileName opts) ++ "_meta.h"
    modYFile = path </> (optFileName opts) ++ "_modules.yml"
    metaYFile = path </> (optFileName opts) ++ "_meta.yml"
    initYFile = path </> (optFileName opts) ++ "_init.yml"
    entityYFile = path </> (optFileName opts) ++ "_entities.yml"
    groupsYFile = path </> (optFileName opts) ++ "_group.yml"

    path = addTrailingPathSeparator (optOutputDir opts)

    debug  = optDebug opts

    profile  = optProfile opts
    logging  = optLogging opts

    tagInfo :: TagInfo
    tagInfo = buildTagInfo allModSymTables allUsedSyms

    targetPath = optTargetDir opts
  in do
    -- make directory
    createDirectoryIfMissing True $ path
    createDirectoryIfMissing True $ path </> "src"
    createDirectoryIfMissing True $ path </> "include"

    -- tag_set files
    hPutStrLn stderr $ "\nGenerating: " ++ tagSetCFile
    writeMetaSetCFile tagSetCFile
    hPutStrLn stderr $ "Generating: " ++ tagSetHFile
    writeMetaSetHFile tagSetHFile tagInfo

      -- policy_rule files
    hPutStrLn stderr $ "Generating: " ++ ruleCFile
    writeRuleCFile ruleCFile debug profile logging topMod policy
                   allModSymTables allUsedSyms tagInfo

    hPutStrLn stderr $ "Generating: " ++ ruleHFile
    writeRuleHFile ruleHFile debug

      -- policy_utils files
    hPutStrLn stderr $ "Generating: " ++ utilsCFile
    writeUtilsCFile utilsCFile tagInfo

    hPutStrLn stderr $ "Generating: " ++ utilsHFile
    writeUtilsHFile utilsHFile

      -- policy_metadata files
    hPutStrLn stderr $ "Generating: " ++ metaHFile
    writeMetaHFile metaHFile tagInfo
    hPutStrLn stderr $ "Generating: " ++ metaYFile
    writeMetaYFile metaYFile tagInfo
    hPutStrLn stderr $ "Generating: " ++ modYFile
    writeModuleYFile modYFile allModSymTables
    hPutStrLn stderr $ "Generating: " ++ groupsYFile
    writeGroupYFile groupsYFile allModSymTables allUsedSyms
    hPutStrLn stderr $ "Generating: " ++ initYFile
    writeInitYFile initYFile allModSymTables allUsedSyms
    hPutStrLn stderr $ "Generating: " ++ entityYFile
    writeEntityYFile entityYFile targetPath
