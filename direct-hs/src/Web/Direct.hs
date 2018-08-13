-- | Client library for Direct.
module Web.Direct
    ( Config(..)
    , defaultConfig
  -- * Login
    , login
    , URL
  -- * Client
    , Client
    , withClient
    , setDomains
    , getDomains
    , setTalkRooms
    , getTalkRooms
    , setMe
    , getMe
    , setUsers
    , getUsers
  -- ** Login information
    , LoginInfo(..)
    , serializeLoginInfo
    , deserializeLoginInfo
  -- * Message
  -- ** Ids
    , DomainId
    , TalkId
    , UserId
    , MessageId
  -- ** Abstract types
  -- *** Domain
    , Domain
    , domainId
    , domainName
  -- *** Talk room
    , TalkType(..)
    , TalkRoom
    , talkId
    , talkType
    , talkUsers
  -- *** User
    , User
    , userId
    , displayName
    , canonicalDisplayName
    , phoneticDisplayName
    , canonicalPhoneticDisplayName
  -- *** Auxiliary data
    , Aux
    , auxMessageId
    , auxTalkId
    , auxUserId
    , defaultAux
  -- ** Message
    , Message(..)
  -- * Sending
    , sendMessage
  -- * Channel
    , Channel
    , withChannel
    , recv
    , send
  -- * Terminating
    , shutdown
  -- *Exceptions
    , Exception(..)
    )
where

import           Web.Direct.Api
import           Web.Direct.Client
import           Web.Direct.Exception
import           Web.Direct.LoginInfo
import           Web.Direct.Message
import           Web.Direct.Types