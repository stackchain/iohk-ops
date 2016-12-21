#!/usr/bin/env nix-shell
#! nix-shell -j 4 -i runhaskell -p 'pkgs.haskellPackages.ghcWithPackages (hp: with hp; [ turtle cassava vector safe ])'

{-# LANGUAGE OverloadedStrings #-}

import Turtle
import CardanoLib
import Data.Monoid ((<>))
import qualified Data.Text as T
import GHC.Conc (threadDelay)


data Command =
    Deploy
  | Destroy
  | FromScratch
  | CheckStatus
  | RunExperiment
  | Build
  deriving (Show)

parser :: Parser Command
parser =
      subcommand "deploy" "Deploy the whole cluster" (pure Deploy)
  <|> subcommand "destroy" "Destroy the whole cluster" (pure Destroy)
  <|> subcommand "build" "Build the application" (pure Build)
  <|> subcommand "fromscratch" "Destroy, Delete, Create, Deploy" (pure FromScratch)
  <|> subcommand "checkstatus" "Check if nodes are accessible via ssh and reboot if they timeout" (pure CheckStatus)
  <|> subcommand "runexperiment" "Deploy cluster and perform measurements" (pure RunExperiment)



args = " -d time-warp" <> nixpath
nixpath = " -I ~/ "
deployment = " deployments/timewarp.nix "


main :: IO ()
main = do
  command <- options "Helper CLI around NixOps to run experiments" parser
  case command of
    Deploy -> deploy args
    Destroy -> destroy args
    FromScratch -> fromscratch args deployment
    CheckStatus -> checkstatus args
    RunExperiment -> runexperiment
    Build -> build
    -- TODO: invoke nixops with passed parameters

runexperiment :: IO ()
runexperiment = do
  -- build
  --checkstatus
  --deploy
  shells (sshForEach args "systemctl stop timewarp") empty
  shells (sshForEach args "rm -f /home/timewarp/node.log") empty
  nodes <- getNodes args
  shells (sshForEach args "systemctl start timewarp") empty
  threadDelay (150*1000000)
  let workDir = "experiment"
  -- TODO: mkdir `date` (CSL)
  shell ("mkdir -p " <> workDir) empty
  sh . using $ parallel nodes $ \node -> scpFromNode args node "/home/timewarp/node.log" (workDir <> getNodeName node <> ".log")

build :: IO ()
build = do
  echo "Building derivation..."
  shells ("nix-build -j 4 --cores 2 tw-sketch.nix" <> nixpath) empty