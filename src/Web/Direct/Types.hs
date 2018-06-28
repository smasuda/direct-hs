{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}

module Web.Direct.Types where

import qualified Control.Exception                as E
import           Data.Aeson                       (FromJSON, ToJSON,
                                                   fieldLabelModifier)
import qualified Data.Aeson                       as Json
import qualified Data.ByteString.Lazy             as B
import qualified Data.Char                        as Char
import qualified Data.MessagePack                 as M
import qualified Data.Text                        as T
import           Data.Typeable                    (Typeable)
import           Data.Word                        (Word64)
import           GHC.Generics                     (Generic)

import qualified Network.MessagePack.Async.Client as Rpc

-- | Direct client.
data Client = Client {
    clientPersistedInfo :: !PersistedInfo
  , clientRpcClient     :: !AnonymousClient
  }

-- | Direct client not logined yet.
type AnonymousClient = Rpc.Client

data PersistedInfo = PersistedInfo {
    persistedInfoDirectAccessToken :: !T.Text
  , persistedInfoIdfv              :: !T.Text
  } deriving (Eq, Show, Generic)

instance FromJSON PersistedInfo where
  parseJSON = Json.genericParseJSON deriveJsonOptions

instance ToJSON PersistedInfo where
  toJSON = Json.genericToJSON deriveJsonOptions
  toEncoding = Json.genericToEncoding deriveJsonOptions

serializePersistedInfo :: PersistedInfo -> B.ByteString
serializePersistedInfo = Json.encode

deserializePersistedInfo :: B.ByteString -> Either String PersistedInfo
deserializePersistedInfo = Json.eitherDecode


data Exception =
      InvalidEmailOrPassword
    | InvalidWsUrl !String
    | UnexpectedReponse !M.Object
  deriving (Eq, Show, Typeable)

instance E.Exception Exception

type DirectInt64 = Word64

type TalkId = DirectInt64


deriveJsonOptions :: Json.Options
deriveJsonOptions = Json.defaultOptions
    { fieldLabelModifier = firstLower . drop (T.length "PersistedInfo")
    }

firstLower :: String -> String
firstLower (x : xs) = Char.toLower x : xs
firstLower _        = error "firstLower: Assertion failed: empty string"

data Message =
    Txt       !TalkId !T.Text
  | Location  !TalkId !T.Text !T.Text -- Address, GoogleMap URL
  | Stamp     !TalkId !Word64 !DirectInt64
  | YesNoQ    !TalkId !T.Text
  | YesNoA    !TalkId !T.Text Bool
  | SelectQ   !TalkId !T.Text ![T.Text]
  | SelectA   !TalkId !T.Text ![T.Text] T.Text
  | TaskQ     !TalkId !T.Text Bool -- False: anyone, True: everyone
  | TaskA     !TalkId !T.Text Bool Bool -- done
  | Other     !TalkId !T.Text

type RspInfo = [(M.Object, M.Object)]

decodeMessage :: RspInfo -> Maybe Message
decodeMessage rspinfo = do
    M.ObjectWord tid <- look "talk_id" rspinfo
    typ              <- look "type" rspinfo
    case typ of
        M.ObjectWord 1 -> do
            msg <- look "content" rspinfo >>= M.fromObject
            if "今ココ：" `T.isPrefixOf` msg then
                let ln = T.lines msg
                in Just $ Location tid (ln !! 1) (ln !! 2)
              else
                Just $ Txt tid msg
        M.ObjectWord 2 -> do
            set <- look "stamp_set" rspinfo >>= M.fromObject
            idx <- look "stamp_index" rspinfo >>= M.fromObject
            Just $ Stamp tid set idx
        M.ObjectWord 501 -> do
            M.ObjectMap m <- look "content" rspinfo
            qst           <- look "question" m >>= M.fromObject
            yon           <- look "response" m >>= M.fromObject
            Just $ YesNoA tid qst yon
        M.ObjectWord 503 -> do
            M.ObjectMap m <- look "content" rspinfo
            qst           <- look "question" m >>= M.fromObject
            opt           <- look "options" m >>= M.fromObject
            idx           <- look "response" m >>= M.fromObject
            let ans = opt !! fromIntegral (idx :: Word64)
            Just $ SelectA tid qst opt ans
        M.ObjectWord 505 -> do
            M.ObjectMap m <- look "content" rspinfo
            ttl           <- look "title" m >>= M.fromObject
            cls'          <- look "closing_type" m >>= M.fromObject
            don           <- look "done" m >>= M.fromObject
            let cls = if cls' == (1 :: Word64) then True else False
            Just $ TaskA tid ttl cls don
        _ -> Just $ Other tid $ T.pack $ show rspinfo
    where look key = lookup (M.ObjectStr key)

encodeMessage :: Message -> [M.Object]
encodeMessage (Txt tid text) = [M.ObjectWord tid, M.ObjectWord 1, M.ObjectStr text]
encodeMessage (Location tid addr url) =
    [M.ObjectWord tid, M.ObjectWord 1, M.ObjectStr (T.unlines ["今ココ：",addr,url])]
encodeMessage (Stamp tid s n) =
    [ M.ObjectWord tid
    , M.ObjectWord 2
    , M.ObjectMap
        [ (M.ObjectStr "stamp_set"  , M.ObjectWord s)
        , (M.ObjectStr "stamp_index", M.toObject n)
        ]
    ]
encodeMessage (YesNoQ tid q) =
    [ M.ObjectWord tid
    , M.ObjectWord 500
    , M.ObjectMap
        [ (M.ObjectStr "question", M.ObjectStr q)
        , (M.ObjectStr "listing" , M.ObjectBool False)
        ]
    ]
encodeMessage (SelectQ tid q as) =
    [ M.ObjectWord tid
    , M.ObjectWord 502
    , M.ObjectMap
        [ (M.ObjectStr "question", M.ObjectStr q)
        , (M.ObjectStr "options" , M.toObject as)
        , (M.ObjectStr "listing" , M.ObjectBool False)
        ]
    ]
encodeMessage (TaskQ tid ttl cls) =
    [ M.ObjectWord tid
    , M.ObjectWord 504
    , M.ObjectMap
        [ (M.ObjectStr "title"       , M.ObjectStr ttl)
        , (M.ObjectStr "closing_type", M.ObjectWord (if cls then 1 else 0))
        ]
    ]

encodeMessage (Other tid text) = [M.ObjectWord tid, M.ObjectWord 1, M.ObjectStr text]

encodeMessage _ = error "encodeMessage"