{-# LANGUAGE OverloadedStrings #-}

module Web.Direct.Map where

import           Data.Maybe       (mapMaybe)
import qualified Data.MessagePack as M


import           Web.Direct.Types
import           Web.Direct.Utils

----------------------------------------------------------------

fromCreateSession :: M.Object -> Maybe User
fromCreateSession (M.ObjectMap m) = do
    user <- look "user" m
    decodeUser user
fromCreateSession _ = Nothing

fromGetAcquaintances :: M.Object -> [User]
fromGetAcquaintances (M.ObjectArray [M.ObjectArray [M.ObjectWord _domain, M.ObjectArray users]])
    = mapMaybe decodeUser users
fromGetAcquaintances _ = []

decodeUser :: M.Object -> Maybe User
decodeUser (M.ObjectMap user) = do
    M.ObjectWord uid     <- look "user_id" user
    M.ObjectStr  dname   <- look "display_name" user
    M.ObjectStr  cdname  <- look "canonical_display_name" user
    M.ObjectStr  pdname  <- look "phonetic_display_name" user
    M.ObjectStr  cpdname <- look "canonical_phonetic_display_name" user
    Just $ User uid dname cdname pdname cpdname
decodeUser _ = Nothing

fromGetDomains :: M.Object -> [Domain]
fromGetDomains (M.ObjectArray arr) = mapMaybe decodeDomain arr
fromGetDomains _                   = []

decodeDomain :: M.Object -> Maybe Domain
decodeDomain (M.ObjectMap m) = do
    M.ObjectWord did   <- look "domain_id" m
    M.ObjectMap  s     <- look "domain" m
    M.ObjectStr  dname <- look "domain_name" s
    Just $ Domain did dname
decodeDomain _ = Nothing

fromGetTalks :: M.Object -> [TalkRoom]
fromGetTalks (M.ObjectArray arr) = mapMaybe decodeTalkRoom arr
fromGetTalks _                   = []

decodeTalkRoom :: M.Object -> Maybe TalkRoom
decodeTalkRoom (M.ObjectMap m) = do
    M.ObjectWord tid <- look "talk_id" m
    M.ObjectWord tp  <- look "type" m
    let typ
            | tp == 1 = PairTalk
            | tp == 2 = case look "talk_name" m of
                Just (M.ObjectStr tname) -> GroupTalk tname
                _                        -> error "decodeTalkRoom"
            | otherwise = UnknownTalk
    M.ObjectArray uids <- look "user_ids" m
    let userIds = mapMaybe extract uids
    Just $ TalkRoom tid typ userIds
  where
    extract (M.ObjectWord uid) = Just uid
    extract _                  = Nothing
decodeTalkRoom _ = Nothing
