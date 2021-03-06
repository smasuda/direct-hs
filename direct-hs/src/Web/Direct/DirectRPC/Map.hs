{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Web.Direct.DirectRPC.Map where

import           Data.Function    (on)
import qualified Data.List        as L
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

fromGetAcquaintances :: M.Object -> [(DomainId, [User])]
fromGetAcquaintances (M.ObjectArray xs) = mapMaybe fromGetAcquaintances' xs
  where
    fromGetAcquaintances' (M.ObjectArray [M.ObjectWord _domain, M.ObjectArray users])
        = Just (_domain, mapMaybe decodeUser users)
    fromGetAcquaintances' _ = Nothing
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

fromGetTalks :: M.Object -> [(DomainId, [TalkRoom])]
fromGetTalks (M.ObjectArray arr) =
    map ((\pair -> (head $ fst pair, snd pair)) . unzip)
        $ L.groupBy ((==) `on` fst)
        . L.sortBy (compare `on` fst)
        $ mapMaybe decodeTalkRoomWithDomainId arr
fromGetTalks _ = []

decodeTalkRoomWithDomainId :: M.Object -> Maybe (DomainId, TalkRoom)
decodeTalkRoomWithDomainId (M.ObjectMap m) = do
    M.ObjectWord did <- look "domain_id" m
    talk             <- decodeTalkRoom $ M.ObjectMap m
    return (did, talk)
decodeTalkRoomWithDomainId _ = Nothing

decodeTalkRoom :: M.Object -> Maybe TalkRoom
decodeTalkRoom (M.ObjectMap m) = do
    M.ObjectWord tid <- look "talk_id" m
    M.ObjectWord tp  <- look "type" m
    let typ
            | tp == 1 = PairTalk
            | tp == 2 = case look "talk_name" m of
                Just (M.ObjectStr tname) -> GroupTalk tname
                _                        -> GroupTalk ""
            | otherwise = UnknownTalk
    M.ObjectArray uids <- look "user_ids" m
    let userIds = mapMaybe extract uids
    Just $ TalkRoom tid typ userIds
  where
    extract (M.ObjectWord uid) = Just uid
    extract _                  = Nothing
decodeTalkRoom _ = Nothing

decodeUploadAuth :: [(M.Object, M.Object)] -> Maybe UploadAuth
decodeUploadAuth rspMap = do
    M.ObjectStr uploadAuthGetUrl <- lookup (M.ObjectStr "get_url") rspMap
    M.ObjectStr uploadAuthPutUrl <- lookup (M.ObjectStr "put_url") rspMap
    M.ObjectWord uploadAuthFileId <- lookup (M.ObjectStr "file_id") rspMap

    M.ObjectMap formObj <- lookup (M.ObjectStr "post_form") rspMap
    M.ObjectStr uploadAuthContentDisposition <- lookup
        (M.ObjectStr "Content-Disposition")
        formObj
    return UploadAuth {..}

----------------------------------------------------------------

decodeTalker :: M.Object -> Maybe (DomainId, TalkId, [UserId], [UserId])
decodeTalker (M.ObjectMap m) = do
    M.ObjectWord did <- look "domain_id" m
    M.ObjectWord tid <- look "talk_id" m
    userIds          <- decodeUserIds =<< look "user_ids" m
    leftUsers        <- decodeLeftUsers =<< look "left_users" m
    return (did, tid, userIds, leftUsers)
decodeTalker _ = Nothing

decodeUserIds :: M.Object -> Maybe [UserId]
decodeUserIds (M.ObjectArray arr) = Just $ mapMaybe decodeUserId arr
  where
    decodeUserId (M.ObjectWord uid) = Just uid
    decodeUserId _                  = Nothing
decodeUserIds _ = Nothing

decodeLeftUsers :: M.Object -> Maybe [UserId]
decodeLeftUsers (M.ObjectArray arr) = Just $ mapMaybe decodeLeftUser arr
  where
    decodeLeftUser (M.ObjectMap m) = do
        M.ObjectWord uid <- look "user_id" m
        return uid
    decodeLeftUser _ = Nothing
decodeLeftUsers _ = Nothing
