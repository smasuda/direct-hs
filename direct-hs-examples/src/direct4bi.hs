import           Control.Arrow            (second)
import           Control.Concurrent       (threadDelay)
import           Control.Monad            (when)
import           Control.Monad.IO.Class   (liftIO)
import qualified Data.ByteString.Lazy     as B
import           Data.Char                (isSpace)
import           Data.List                (break)
import qualified Data.Text                as T
import qualified System.Console.Haskeline as Hl
import           System.Environment       (getArgs)
import qualified System.FilePath          as FP
import           System.IO                (hPutStrLn, stderr)
import           Text.Pretty.Simple       (pPrint)
import           Text.Read                (readMaybe)

import qualified Web.Direct               as D

import           Common                   hiding (jsonFileName)


main :: IO ()
main = do
    jsonFileName <- head <$> getArgs
    let histFile = FP.takeBaseName jsonFileName ++ ".history.txt"
    pInfo <- dieWhenLeft . D.deserializeLoginInfo =<< B.readFile jsonFileName
    hasT <- Hl.runInputT Hl.defaultSettings Hl.haveTerminalUI
    let prompt = if hasT then consolePrompt else ""
    D.withClient
        D.defaultConfig
            { D.directCreateMessageHandler = \_client msg -> printMessage msg >> putStrLn prompt
            , D.directWaitCreateMessageHandler = False
            }
        pInfo
        (Hl.runInputT Hl.defaultSettings { Hl.historyFile = Just histFile } . startLoop prompt)


type State = Maybe D.TalkId

type Prompt = String


consolePrompt :: String
consolePrompt = "direct4bi> "


startLoop :: Prompt -> D.Client -> Hl.InputT IO ()
startLoop prompt client = do
    hasT <- Hl.haveTerminalUI
    when hasT
        $ Hl.outputStrLn "Connected to direct4b.com. Enter \"help\" to see the available commands"
    loop Nothing prompt client


loop :: State -> Prompt -> D.Client -> Hl.InputT IO ()
loop st prompt client = do
    mcmd <- fmap parseCommand <$> Hl.getInputLine prompt
    case mcmd of
        Just (command, args) ->
            if command == "quit"
              then return ()
              else do
                  newSt <- liftIO $ runCommand st client command args
                  loop newSt prompt client
        _ -> return ()


parseCommand :: String -> (String, String)
parseCommand = second (dropWhile isSpace) . break isSpace


runCommand :: State -> D.Client -> String -> String -> IO State
runCommand st  client     "r"  arg =
    case readMaybe arg of
        Just roomId -> do
            rooms <- D.getTalkRooms client
            if any ((== roomId) . D.talkId) rooms
              then return $ Just roomId
              else do
                  hPutStrLn stderr $ "Room#" ++ show roomId ++ " is not your room!"
                  return st
        _ -> do
            hPutStrLn stderr $ "Invalid room ID: " ++ show arg
            return st
runCommand st  client     "p"  arg = do
    case st of
        Just roomId -> do
            result <- D.sendMessage client (D.Txt $ T.pack arg) roomId
            case result of
                Right mid -> putStrLn $ "Successfully created message#" ++ show mid ++ "."
                Left ex -> putStrLn $ "ERROR creating a message: " ++ show ex
        _ -> do
            hPutStrLn stderr $ "No room ID configured! Run r <room_id> to configure current room ID!"
    return st
runCommand st _client "sleep"  arg = do
    case (readMaybe arg) :: Maybe Double of
        Just seconds -> threadDelay $ round $ seconds * 1000 * 1000
        _            -> hPutStrLn stderr $ "Invalid <seconds>: " ++ show arg
    return st
runCommand st _client  "help" _arg = do
    putStrLn "r <talk_room_id>: Switch the current talk room by <talk_room_id>"
    putStrLn "p <message>: Post <message> to the current talk room."
    putStrLn "sleep <seconds>: Sleep for <seconds> seconds."
    putStrLn "quit: Quit this application."
    putStrLn "help: Print this message."
    return st
runCommand st _client   other _arg = do
    hPutStrLn stderr $ "Unknown command " ++ show other ++ "."
    return st


printMessage :: (D.Message, D.MessageId, D.TalkRoom, D.User) -> IO ()
printMessage (msg, mid, room, user) = do
    putStrLn $ "\nMessage#" ++ show mid ++ "at room#" ++ show (D.talkId room) ++ " by user#" ++ show (D.userId user) ++ ":"
    pPrint msg
