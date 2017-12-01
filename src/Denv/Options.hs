{-# LANGUAGE OverloadedStrings #-}

module Denv.Options where

import           Data.Semigroup      ((<>))
import           Denv.Types
import           Options.Applicative


data DenvArgs = DenvArgs { denvCommand :: Command }


data Command = Kube KubeProjectName (Maybe KubeNamespace)
             | Pass (Maybe PasswordStorePath)
             | Deactivate

passPathOpt = optional $ strOption (
                     long "password-store-path"
                     <> short 'p'
                     <> metavar "PATH"
                     <> help "Full path to password store directory.")

kubeNamespaceOpt = optional $ strOption (
                     long "kube-namespace"
                     <> short 'n'
                     <> metavar "NAMESPACE"
                     <> help "Kube Namespace. Example: kube-system or default.")

kubeProjectOpt = strOption (
                   long "kube-project"
                   <> short 'p'
                   <> metavar "YAMLPATH"
                   <> help "Full path to kube config yaml file.")

cmdKube = command "kube" infos
    where infos = info options desc
          desc = progDesc "Set kube environment."
          options = Kube <$> kubeProjectOpt <*> kubeNamespaceOpt

cmdPass = command "pass" infos
    where infos = info options desc
          desc = progDesc "Set pass environment."
          options = Pass <$> passPathOpt

cmdDeactivate = command "deactivate" infos
    where infos = info options desc
          desc = progDesc "Deactivate environment"
          options = pure Deactivate

argCmds = subparser (cmdKube <> cmdPass <> cmdDeactivate)

denvArgs :: Parser DenvArgs
denvArgs = DenvArgs <$> argCmds
