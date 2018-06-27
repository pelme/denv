{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GADTs #-}

module Denv.Utils where

import RIO
import Prelude (getLine, putStr)

import System.Environment (lookupEnv)
import System.Exit (die)
import Data.List (foldl, intercalate)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.FilePath ((</>))
import Text.Parsec (parse)
import System.FilePath.Posix (splitPath)
import System.Directory ( getHomeDirectory )
import qualified LoadEnv.Parse as LE

import Denv.Types

mkEscapedText :: T.Text -> T.Text
mkEscapedText x = "\"" <> x <> "\""

ps1 :: T.Text
ps1 = mkEscapedText "$PS1"

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe x = either (const Nothing) (\r -> Just r) x

withVarTracking :: Maybe T.Text -> [DenvVariable] -> [DenvVariable]
withVarTracking x xs =
  case x of
    Nothing ->
      xs <>
      [ Set DenvSetVars $ (texify xs) <> "," <> appendTracking
      ]
    Just x' ->
      xs <>
      [ Set DenvSetVars $ (texify xs) <> "," <> x' <> appendTracking
      ]
  where
    getText :: DenvVariable -> T.Text
    getText x' = case x' of
      (Set v _) ->T.pack $ show v
      (Unset _) -> ""
    nonEmpty e = e /= ""
    -- We don't want to unset PS1 as that would leave us with an empty prompt.
    -- Hence we filter it out of the vars we're tracking for deactivation
    isps1 e = e /= "PS1"
    appendTracking = (T.pack $ show DenvSetVars)
    texify :: [DenvVariable] -> T.Text
    texify xs' = T.intercalate "," $ filter isps1 $ filter nonEmpty $ map getText xs'

checkEnv :: IO ()
checkEnv = do
  isActiveEnv <- lookupEnv "_DENV_SET_VARS"
  case isActiveEnv of
    Nothing -> return ()
    Just _ -> die "Env already active. Please run `denv deactivate` first or use the \"exec mode\" for your command."

envify :: DenvVariable -> T.Text
envify (Set k v) = "export " <> (T.pack $ show k) <> "=" <> v <> ";" <> "\n"
envify (Unset k) = "unset " <> (T.pack $ show k) <> ";" <> "\n"

toEnv :: [DenvVariable] -> T.Text
toEnv xs = T.intercalate "" (map envify xs)

writeRc :: [DenvVariable] -> IO ()
writeRc env = do
  h <- getHomeDirectory
  let rc = h </> ".denv"
  TIO.writeFile rc (toEnv env)

writeRcWithPredefined :: T.Text -> [DenvVariable] -> IO ()
writeRcWithPredefined c env = do
  h <- getHomeDirectory
  let rc = h </> ".denv"
  TIO.writeFile rc c
  TIO.appendFile rc (toEnv env)

parseEnvFileOrDie :: FilePath -> T.Text -> IO T.Text
parseEnvFileOrDie p c = do
  let deac = parse LE.parseEnvironment p (T.unpack c)
  case deac of
    Left err -> die $ show err
    Right deac' -> do
      let deac'' =
            foldl
              (\acc (k :: String, _ :: String) -> (T.pack k) <> "," <> acc)
              ""
              deac'
      return deac''

mkRawEnvShort :: FilePath -> String
mkRawEnvShort xs = intercalate "" $ drop (length fragments - 2) fragments
  where fragments = splitPath xs

mkPassDirShort :: FilePath -> String
mkPassDirShort xs = intercalate "" $ drop (length fragments - 2) fragments
  where fragments = splitPath xs

promptLine :: String -> IO String
promptLine prompt = do
    putStr prompt
    hFlush stdout
    getLine
