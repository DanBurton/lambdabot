--
-- Copyright (c) 2004 Donald Bruce Stewart - http://www.cse.unsw.edu.au/~dons
-- GPL version 2 or later (see http://www.gnu.org/copyleft/gpl.html)
--

--
-- | A Haskell evaluator for the pure part, using plugs
--
-- requires the 'runplugs' utility available with the hs-plugins library.
-- in '$hsplugins/examples/hmake/one-shot'
--
module Plugin.Plugs where

import Plugin
import Lib.Parser

PLUGIN Plugs

instance Module PlugsModule () where
    moduleCmds   _ = ["run"]
    moduleHelp _ _ = "run <expr>\nYou have Haskell, 3 seconds and no IO. Go nuts!"
    process_ _ _ s = ios (plugs s)

binary :: String
binary = "./runplugs"

plugs :: String -> IO String
plugs src = do
    -- first, verify the source is actually a Haskell 98 expression, to
    -- avoid code injection bugs.
    case parseExpr src of
        ParseFailed _ e -> return $ " " ++ e
        ParseOk     _   -> do
            (out,err,_) <- popen binary [] (Just src)
            let o = unlines . munge $ out
                e = unlines . munge $ err
            return $ case () of {_
                | null o && null e -> "Terminated\n"
                | null o           -> " " ++ e
                | otherwise        -> " " ++ o
            }

            where munge = take 3 . lines . expandTab . dropWhile (=='\n') . dropNL . clean_ 

--
-- Clean up runplugs' output
--
clean_ :: String -> String
clean_ s | Just _         <- no_io      `matchRegex`    s = "No IO allowed\n"
        | Just _         <- terminated `matchRegex`    s = "Terminated\n"
        | Just _         <- hput       `matchRegex`    s = "Terminated\n"
        | Just _         <- stack_o_f  `matchRegex`    s = "Stack overflow\n"
        | Just _         <- loop       `matchRegex`    s = "Loop\n"
        | Just _         <- undef      `matchRegex`    s = "Undefined\n"
        | Just _         <- type_sig   `matchRegex`    s = "Add a type signature\n"
        | Just (_,m,_,_) <- ambiguous  `matchRegexAll` s = m
        | Just (_,_,b,_) <- inaninst   `matchRegexAll` s = clean_ b
        | Just (_,_,b,_) <- irc        `matchRegexAll` s = clean_ b
        | Just (_,m,_,_) <- nomatch    `matchRegexAll` s = m
        | Just (_,m,_,_) <- notinscope `matchRegexAll` s = m
        | Just (_,m,_,_) <- hsplugins `matchRegexAll`  s = m
        | Just (a,_,_,_) <- columnnum `matchRegexAll`  s = a
        | Just (a,_,_,_) <- extraargs `matchRegexAll`  s = a
        | Just (_,_,b,_) <- filename' `matchRegexAll`  s = clean_ b
        | Just (a,_,b,_) <- filename  `matchRegexAll`  s = a ++ clean_ b
        | Just (a,_,b,_) <- filepath `matchRegexAll`   s = a ++ clean_ b
        | Just (a,_,b,_) <- runplugs  `matchRegexAll`  s = a ++ clean_ b
        | otherwise      = s
    where
        -- s/<[^>]*>:[^:]: //
        type_sig   = mkRegex "add a type signature that fixes these type"
        no_io      = mkRegex "No instance for \\(Show \\(IO"
        terminated = mkRegex "waitForProc"
        stack_o_f  = mkRegex "Stack space overflow"
        loop       = mkRegex "runplugs: <<loop>>"
        irc        = mkRegex "\n*<irc>:[^:]*:[^:]*:\n*"
        filename   = mkRegex "\n*<[^>]*>:[^:]*:\\?[^:]*:\\?\n* *"
        filename'  = mkRegex "/tmp/.*\\.hs[^\n]*\n"
        filepath   = mkRegex "\n*/[^\\.]*.hs:[^:]*:\n* *"
        undef      = mkRegex "Prelude.undefined"
        ambiguous  = mkRegex "Ambiguous type variable `a\' in the constraints"
        runplugs   = mkRegex "runplugs: "
        notinscope = mkRegex "Variable not in scope:[^\n]*"
        hsplugins  = mkRegex "Compiled, but didn't create object"
        extraargs  = mkRegex "[ \t\n]*In the [^ ]* argument"
        columnnum  = mkRegex " at <[^\\.]*\\.[^\\.]*>:[^ ]*"
        nomatch    = mkRegex "Couldn't match[^\n]*\n"
        inaninst   = mkRegex "^[ \t]*In a.*$"
        hput       = mkRegex "<stdout>: hPutStr"

------------------------------------------------------------------------
--
-- Plugs tests:
--  * too long, should be terminated.
--      @plugs last [ 1 .. 100000000 ]
--      @plugs last [ 1 .. ]
--      @plugs product [1..]
--      @plugs let loop () = loop () in loop () :: ()
--
--  * stack oflow
--      @plugs scanr (*) 1 [1..]
--
--  * type errors, or module scope errors
--      @plugs unsafePerformIO (return 42)
--      @plugs GHC.Exts.I# 1#
--      @plugs $( Language.Haskell.THSyntax.Q (putStr "heya") >> [| 3 |] )
--      @plugs Data.Array.listArray (minBound::Int,maxBound) (repeat 0)
--
--  * syntax errors
--      @plugs map foo bar
--      @plugs $( [| 1 |] )
--
--  * success
--      @plugs head [ 1 .. ]
--      @plugs [1..]
--      @plugs last $ sort [1..100000 ]
--      @plugs let fibs = 1:1:zipWith (+) fibs (tail fibs) in take 20 fibs
--      @plugs sort [1..10000]
--      @plugs ((error "throw me") :: ())
--      @plugs Random.randomRs (0,747737437443734::Integer) (Random.mkStdGen 1122)
--
-- More at http://www.scannedinavian.org/~shae/joyXlogs.txt
--
