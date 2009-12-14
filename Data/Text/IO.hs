-- |
-- Module      : Data.Text.IO
-- Copyright   : (c) Bryan O'Sullivan 2009
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : GHC
--
-- Support for text I\/O.
--

module Data.Text.IO
    (
    -- * Locale support
    -- $locale
    -- * File-at-a-time operations
      readFile
    , writeFile
    , appendFile
    -- * Operations on handles
    , hGetContents
    , hGetLine
    , hPutStr
    , hPutStrLn
    -- * Special cases for standard input and output
    , interact
    , getContents
    , getLine
    , putStr
    , putStrLn
    ) where

import Data.Text (Text)
import Prelude hiding (appendFile, getContents, getLine, interact, putStr,
                       putStrLn, readFile, writeFile)
import System.IO (Handle, hPutChar, stdin, stdout)
import qualified Data.ByteString as B
import Data.Text.Encoding (decodeUtf8, encodeUtf8)

-- | The 'readFile' function reads a file and returns the contents of
-- the file as a string.  The entire file is read strictly, as with
-- 'getContents'.
readFile :: FilePath -> IO Text
readFile = fmap decodeUtf8 . B.readFile

-- | Write a string to a file.  The file is truncated to zero length
-- before writing begins.
writeFile :: FilePath -> Text -> IO ()
writeFile p = B.writeFile p . encodeUtf8

-- | Write a string the end of a file.
appendFile :: FilePath -> Text -> IO ()
appendFile p = B.appendFile p . encodeUtf8

-- | Read the remaining contents of a handle as a string.
hGetContents :: Handle -> IO Text
hGetContents = fmap decodeUtf8 . B.hGetContents

-- | Read a single line from a handle.
hGetLine :: Handle -> IO Text
hGetLine = fmap decodeUtf8 . B.hGetLine

-- | Write a string to a handle.
hPutStr :: Handle -> Text -> IO ()
hPutStr h = B.hPutStr h . encodeUtf8

-- | Write a string to a handle, followed by a newline.
hPutStrLn :: Handle -> Text -> IO ()
hPutStrLn h t = B.hPutStrLn h (encodeUtf8 t) >> hPutChar h '\n'

-- | The 'interact' function takes a function of type @Text -> Text@
-- as its argument. The entire input from the standard input device is
-- passed to this function as its argument, and the resulting string
-- is output on the standard output device.
interact :: (Text -> Text) -> IO ()
interact f = B.interact (encodeUtf8 . f . decodeUtf8)

-- | Read all user input on 'stdin' as a single string.
getContents :: IO Text
getContents = hGetContents stdin

-- | Read a single line of user input from 'stdin'.
getLine :: IO Text
getLine = hGetLine stdin

-- | Write a string to 'stdout'.
putStr :: Text -> IO ()
putStr = hPutStr stdout

-- | Write a string to 'stdout', followed by a newline.
putStrLn :: Text -> IO ()
putStrLn = hPutStrLn stdout

-- $locale
--
-- Under GHC 6.10 and earlier, the system I\/O libraries do not
-- support locale-sensitive I\/O.  All data read by functions in this
-- module is decoded as UTF-8, and before data is written, it is first
-- encoded as UTF-8.
--
-- Beginning with GHC 6.12, text I\/O is performed using the system or
-- handle's current locale.
