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

module Main where

import System.IO
import Control.Monad
import System.Environment
import System.Exit
import System.Console.GetOpt
import Data.List
import Data.Either

import AST
import PolicyModules
import Generator
import Symbols
import Validate
import CommonFn
import CommonTypes
import ErrorMsg

options :: [ OptDescr (Options -> IO Options) ]
options =
    [ Option "v" ["version"]
        (NoArg
            (\_ -> do
                hPutStrLn stderr "Policy Tool 42"
                exitWith ExitSuccess))
        "Print random number"
 
    , Option "m" ["module-dir"]
        (ReqArg
             (\arg opt -> return opt { optModuleDir = arg })
            "<module-dir>")
        "Set path to base module dir"
 
    , Option "t" ["target-dir"]
        (ReqArg
             (\arg opt -> return opt { optTargetDir = arg })
            "<target-dir>")
        "Set path to base target description dir"
 
    , Option "f" ["file-prefix"]
        (ReqArg
             (\arg opt -> return opt { optFileName = arg })
            "<file-prefix>")
        "Set prefix for generated files"
 
    , Option "o" ["output"]
        (ReqArg
            (\arg opt -> return opt { optOutputDir = arg })
            "<output-dir>")
        "Root of output directory tree"
 
    , Option "d" ["debug"]
        (NoArg
            (\opt -> return opt { optDebug = True }))
        "Enable policy evaluator debug messages"
    , Option "i" ["ir"]
        (NoArg
            (\opt -> return opt { optIR = True }))
        "Dump AST and symbols for policy-tool debug"
    , Option "h" ["help"]
        (NoArg displayHelp)
        "Show help"
    ]

displayHelp :: Options -> IO Options
displayHelp _ = do
  prg <- getProgName
  let cl = prg ++ " <options> <qualified.module.policy>" in do
    hPutStrLn stderr (usageInfo cl options)
    hPutStrLn stderr "Ex:   policy-tool -m path/to/mods -o path/to/gen my.cool.securityPolicy"
    hPutStrLn stderr "      will build \"securityPolicy\" found in: path/to/mods/my/cool.dpl"
    exitWith $ ExitFailure 1

verStr :: Integer -> String
verStr n = show n

main :: IO ()
main = do
    args <- getArgs
    (opts, topPolicyName) <- handle args

    case checkErrs opts topPolicyName of
      [] -> do
        processMods opts topPolicyName
      msgs -> do
        hPutStrLn stderr $ unlines msgs


optFldErrs = [ (optModuleDir, "Error: missing -m <module directory path>")
             , (optTargetDir, "Error: missing -t <target directory path>")
             , (optOutputDir, "Error: missing -o <output directory path>")
             ]

checkErrs  :: Options -> [String] -> [String]
checkErrs opts topPolicyName = map snd $ filter isError optFldErrs
  where
    isError (f,e) = f opts == ""

processMods :: Options -> [String] -> IO()
processMods opts [] = do
  hPutStrLn stderr "\nError no policy specified"
processMods opts topPolicyName = do
    parsedMods <- getAllModules opts topPolicyName
    case parsedMods of
          Left errs -> do
            hPutStrLn stderr "\nError during module loading."
            hPutStrLn stderr $ unlines $ errs
            exitFailure
          Right modules -> case buildSymbolTables modules of
                             Left errs -> do
                               hPutStrLn stderr "\nError building Symbol Tables."
                               hPutStrLn stderr $ unlines $ errs
                               exitFailure
                             Right symbols -> do
                               hPutStrLn stdout "\nBuilt Symbol Tables."
                               when (optIR opts) $ genSymbolsFile symbols
                               case locateMain topPolicyName symbols of
                                 Right (mainModule, mainPolicyDecl) -> do
                                   hPutStrLn stdout "Located main policy."
                                   case validateMain symbols mainModule mainPolicyDecl of
                                     Right uniqueSyms -> do
                                       hPutStrLn stdout "Validated main policy.\n"
                                       when (optIR opts) $ genASTFile $ Just mainPolicyDecl
                                       case validateModuleRequires symbols (uniqueMods uniqueSyms) of
                                         Right uniqueReqs -> do
                                           hPutStrLn stdout "Validated requires.\n"
                                           genFiles opts symbols uniqueSyms uniqueReqs mainModule $ Just mainPolicyDecl
                                           hPutStrLn stderr "\nPolicy implementation generated successfully.\n"
                                           exitSuccess
                                         Left errs -> do
                                           hPutStrLn stderr "\nError Unable to validate requires: " 
                                           hPutStrLn stderr $ unlines $ errs
                                           exitFailure                                         
                                     Left errs -> do
                                       hPutStrLn stderr "\nError Unable to validate main policy: " 
                                       hPutStrLn stderr $ unlines $ errs
                                       exitFailure
                                 Left errs -> do
                                   hPutStrLn stderr "\nError Unable to locate main policy: " 
                                   hPutStrLn stderr $ unlines $ errs
                                   exitFailure
      where
        uniqueMods :: [(ModName, QSym)] -> [ModName]
        uniqueMods = nubSort . fst . unzip

reportErrors :: String -> [Either ErrMsg (ModuleDecl QSym)] -> IO ()
reportErrors msg ms = do
  hPutStrLn stderr msg
  hPutStrLn stderr $ unlines $ lefts ms
--  hPutStrLn stderr "Try the following:"
--  hPutStrLn stderr $ unlines $ policyDescriptions knownPolicies

   
handle :: [String] -> IO (Options, [String])
handle [] = do
  _ <- displayHelp defaultOptions
  return (defaultOptions, [])
handle args = do    
    -- Parse options, getting a list of option actions
    let (actions, nonOptions, _errors) = getOpt RequireOrder options args
 
    -- Here we thread startOptions through all supplied option actions
    opts <- foldl (>>=) (return defaultOptions) actions
 
    let Options { optIR = ir
                , optOutputDir = _output
                , optFileName = _fileName   } = opts
 
    when ir (hPutStrLn stderr "Generating in verbose mode:")

      -- be sure to sort to make command line deterministic
    return (opts, sort nonOptions)
