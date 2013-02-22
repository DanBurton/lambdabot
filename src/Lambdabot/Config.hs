--
-- | Configuration data for lambdabot
--
module Lambdabot.Config where

-- | The 'Config' type provides configurations for lambdabot. It is used
--   when lambdabot is started to determine the name of lambdabot, what
--   IRC-network lambdabot should join, which channels lambdabot should
--   join upon successful connection, etc.
--
data Config = Config {
        verbose :: Bool,
        
        proxy     :: Maybe ([Char], Integer), -- ^ A proxy given as
                                              --   a pair of host and port.

        -- | which ghci to use (in "\@type")
        ghci        :: FilePath,
        outputDir   :: FilePath,

        -- | what prefixes to use for commands
        commandPrefixes :: [String],

        -- | what prefixes to use for Haskell evalution
        evalPrefixes :: [String],

        -- | Particular commands we'd like to disable
        -- (to disable whole plugins, remove them from Modules.hs)
        disabledCommands :: [String]
}

--
-- Useful defaults for #haskell.
--
config :: Config
config = Config {
        verbose                 = False,
        
        proxy                   = Nothing, -- Just ("www-proxy",3128),

        ghci                    = "ghci",
        outputDir               = "State/",

        commandPrefixes         = ["@","?"],

        evalPrefixes            = [">"],

        disabledCommands        = []

   }