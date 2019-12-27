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

{-# LANGUAGE TemplateHaskell #-}

module Main where

import System.IO             (hPutStrLn, stderr, stdout)
import System.IO.Error       (IOError,ioeGetErrorString)
import System.Environment    (getProgName,getArgs)
import System.Exit           (exitWith,ExitCode(..),exitFailure,exitSuccess)
import System.Console.GetOpt
import System.Process        (readProcess)
import Control.Monad         (when)
import Control.Exception     (catch)
import Data.Char             (isSpace)
import Data.List             (nub, sort)
import Data.Either           (lefts)
import Data.Version          (showVersion)
import Language.Haskell.TH   (stringE,runIO)
import Paths_policy_tool     (version)

import AST
import PolicyModules (getAllModules)
import Generator     (genSymbolsFile, genASTFile, genFiles)
import Symbols       (buildSymbolTables)
import Validate      (locateMain, validateMain, validateModuleRequires)
import CommonTypes   (Options(..), defaultOptions)
import ErrorMsg      (ErrMsg)

gitHash :: String
gitHash = filter (not . isSpace) $(stringE =<< runIO (catch (readProcess "git" ["rev-parse", "--short", "HEAD"] [])
                                                     (\e -> return $ ioeGetErrorString (e :: IOError))))

options :: [ OptDescr (Options -> IO Options) ]
options =
    [ Option "v" ["version"]
        (NoArg
            (\_ -> do
                hPutStrLn stderr $ "Policy Tool v" ++ showVersion version ++ " (git revision: "++gitHash++")"
                exitWith ExitSuccess))
        "Print random number"

    , Option "m" ["module-dir"]
        (ReqArg
             (\arg opt ->
                 return $ opt { optModuleDir = arg:(optModuleDir opt)})
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

    case checkErrs opts of
      [] -> do
        processMods opts topPolicyName
      msgs -> do
        hPutStrLn stderr $ unlines msgs


optFldErrs :: [(Options -> Bool, [Char])]
optFldErrs = [ (\o -> optModuleDir o == [],
                "Error: missing -m <module directory path>")
             , (\o -> optTargetDir o == "",
                "Error: missing -t <target directory path>")
             , (\o -> optOutputDir o == "",
                "Error: missing -o <output directory path>")
             ]

checkErrs  :: Options -> [String]
checkErrs opts = map snd $ filter (\(test,_) -> test opts) optFldErrs

processMods :: Options -> [String] -> IO()
processMods _ [] = do
  hPutStrLn stderr "\nError no policy specified"
processMods opts topPolicyName = do
    parsedMods <- getAllModules opts topPolicyName
    case parsedMods of
      Left errs -> do
        hPutStrLn stderr "\nError during module loading."
        hPutStrLn stderr $ unlines $ errs
        exitFailure
      Right modules ->
        case buildSymbolTables modules of
          Left errs -> do
            hPutStrLn stderr "\nError building Symbol Tables."
            hPutStrLn stderr $ unlines $ errs
            exitFailure
          Right symbols -> do
            hPutStrLn stdout "\nBuilt Symbol Tables."
            when (optIR opts) $ genSymbolsFile symbols
            case locateMain topPolicyName symbols of
              Right (mainModule, mainPolicyDecl) -> do
                hPutStrLn stdout "Located top-level policy."
                case validateMain symbols mainModule mainPolicyDecl of
                  Right uniqueSyms -> do
                    hPutStrLn stdout "Validated top-level policy.\n"
                    when (optIR opts) $ genASTFile symbols
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
                    hPutStrLn stderr "\nError Unable to validate top-level policy: "
                    hPutStrLn stderr $ unlines $ errs
                    exitFailure
              Left errs -> do
                hPutStrLn stderr "\nError while locating top-level policy: "
                hPutStrLn stderr $ unlines $ errs
                exitFailure
      where
        uniqueMods :: [(ModName, QSym)] -> [ModName]
        uniqueMods = nub . sort . fst . unzip

reportErrors :: String -> [Either ErrMsg (ModuleDecl QSym)] -> IO ()
reportErrors msg ms = do
  hPutStrLn stderr msg
  hPutStrLn stderr $ unlines $ lefts ms

handle :: [String] -> IO (Options, [String])
handle [] = do
  _ <- displayHelp defaultOptions
  return (defaultOptions, [])
handle args = do
    -- Parse options, getting a list of option actions
    let (actions, nonOptions, _errors) = getOpt RequireOrder options args

    -- Here we thread startOptions through all supplied option actions
    opts <- foldl (>>=) (return defaultOptions) actions

    when (optIR opts) (hPutStrLn stderr "Generating in verbose mode:")

      -- be sure to sort to make command line deterministic
    return (opts, sort nonOptions)
