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
import Validate



options :: [ OptDescr (Options -> IO Options) ]
options =
    [ Option "i" ["ir"]
        (NoArg
            (\opt -> return opt { optIR = True }))
        "Dump IR for policy-tool debug"
    , Option "o" ["output"]
        (ReqArg
            (\arg opt -> return opt { optOutputDir = arg })
            "<output-dir>")
        "Output directory path, should point to .../dover-os dir"
 
    , Option "d" ["debug"]
        (NoArg
            (\opt -> return opt { optDebug = True }))
        "Enable debug messages from pump miss handler"
    ]
{-
    , Option "r" ["rules"]
        (NoArg
            (\opt -> return opt { optRules = True }))
        "Pretty print rules to console"

    , Option "p" ["profile"]
        (NoArg
            (\opt -> return opt { optProfile = True }))
        "Profile number of rule insertions"
    ]
    , Option "l" ["logging"]
        (NoArg
            (\opt -> return opt { optLogging = True }))
        "Log rule violations and allow to continue"

    , Option "m" ["metadata"]
        (ReqArg
             (\arg opt -> error "-m no longer needed, use -o .../dover-os") --return opt { optMetaData = True, optMetaDataDir = arg })
            "<output-dir>")
        "Deprecated, use -o .../dover-os instead"
 
    , Option "v" ["version"]
        (NoArg
            (\_ -> do
                hPutStrLn stderr "Policy Tool Too"
--                hPutStrLn stderr $ unlines $ policyVersions knownPolicies
                exitWith ExitSuccess))
        "Print policy versions"
 
    , Option "h" ["help"]
        (NoArg displayHelp)
        "Show help"
    ]
-}
displayHelp :: Options -> IO Options
displayHelp _ = do
  prg <- getProgName
  let cl = prg ++ " <options> <main.policy.name>" in do
    hPutStrLn stderr "\nSpecify fully qualified top level policy name:"
    hPutStrLn stderr (usageInfo cl options)
    exitWith $ ExitFailure 1

  {-
policyDescriptions cp = map document cp
  where
    document p = "      " ++ pName p ++ " - "++ (pDescr p)
                
policyVersions cp = map document cp
  where
    document p = "      " ++ pName p ++ " : "++ ((verStr . pVer)  p)
-}
  
verStr :: Integer -> String
verStr n = show n

main :: IO ()
main = do
    args <- getArgs
    (opts, topPolicyName) <- handle args

    modules <- getAllModules topPolicyName
    
    case validateModules modules of
          Left errs -> do
            hPutStrLn stderr "\nError during module validation (validateModules)."
            hPutStrLn stderr $ unlines $ errs
          Right symbols -> do
            when (optIR opts) $ genSymbolsFile symbols
            case validateMain topPolicyName symbols of
                  Right mainPolicy ->
                    let ePolicy = elabPolicy symbols mainPolicy in do
                      when (optIR opts) $ genASTFile $ ePolicy 
                      genFiles opts symbols mainPolicy 
                      hPutStrLn stderr "\nPolicy implementation generated successfully.\n"
                  Left errs -> do
                    hPutStrLn stderr "\nError in main policy."
                    hPutStrLn stderr $ unlines $ errs

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
